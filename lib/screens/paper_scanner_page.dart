import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import 'paper_detail_page.dart';

class PaperScannerPage extends StatefulWidget {
  const PaperScannerPage({super.key});

  @override
  State<PaperScannerPage> createState() => _PaperScannerPageState();
}

class _PaperScannerPageState extends State<PaperScannerPage>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _hasHandledResult = false;
  bool _isInitializing = true;
  bool _isScannerReady = false;
  String? _scannerError;
  bool _permissionPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isSupportedPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _initializeScanner();
      });
    } else {
      _isInitializing = false;
      _isScannerReady = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSupportedPlatform) return;
    if (!_isScannerReady) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_controller.stop());
      return;
    }

    if (state == AppLifecycleState.resumed && !_hasHandledResult) {
      unawaited(_controller.start());
    }
  }

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _initializeScanner() async {
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _scannerError = null;
      _hasHandledResult = false;
      _isScannerReady = false;
      _permissionPermanentlyDenied = false;
    });

    try {
      final permissionOk = await _ensureCameraPermission();
      if (!permissionOk) {
        if (!mounted) return;
        setState(() {
          _isInitializing = false;
          _isScannerReady = false;
        });
        return;
      }

      await _controller.start().timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isScannerReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isScannerReady = false;
        _scannerError =
            'Could not start camera scanner. Check camera permission and try again.';
      });
    }
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;

    if (status.isGranted) return true;

    if (status.isDenied || status.isRestricted || status.isLimited) {
      status = await Permission.camera.request();
      if (status.isGranted) return true;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      setState(() {
        _permissionPermanentlyDenied = true;
        _scannerError =
            'Camera permission is blocked. Enable camera access in app settings.';
      });
      return false;
    }

    if (!mounted) return false;
    setState(() {
      _scannerError = 'Camera permission denied. Please allow camera access.';
    });
    return false;
  }

  Future<void> _handleCode(String rawValue) async {
    if (_hasHandledResult) return;

    final value = rawValue.trim();
    if (value.isEmpty) return;

    setState(() => _hasHandledResult = true);
    unawaited(_controller.stop());

    final appState = AppStateScope.of(context);

    final byId = appState.paperById(value);
    if (byId != null) {
      await appState.recordView(byId.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PaperDetailPage(paperId: byId.id)),
      );
      return;
    }

    final uri = Uri.tryParse(value);
    if (uri != null) {
      final paperId = _extractPaperId(uri);
      if (paperId != null) {
        final fromUri = appState.paperById(paperId);
        if (fromUri != null) {
          await appState.recordView(fromUri.id);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaperDetailPage(paperId: fromUri.id),
            ),
          );
          return;
        }
      }

      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        if (!mounted) return;
        final shouldOpen =
            await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Open scanned link?'),
                content: Text(value),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Open'),
                  ),
                ],
              ),
            ) ??
            false;

        if (shouldOpen) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!mounted) return;
          Navigator.pop(context);
          return;
        }
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No matching paper found for this code.')),
    );
    setState(() => _hasHandledResult = false);
    unawaited(_controller.start());
  }

  String? _extractPaperId(Uri uri) {
    final idFromQuery =
        uri.queryParameters['paperId'] ?? uri.queryParameters['id'];
    if (idFromQuery != null && idFromQuery.trim().isNotEmpty) {
      return idFromQuery.trim();
    }

    final segments = uri.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) return null;

    if (uri.scheme == 'passit' &&
        segments.length >= 2 &&
        segments.first == 'paper') {
      return segments[1];
    }

    if (segments.length >= 2 && segments[segments.length - 2] == 'paper') {
      return segments.last;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget body;
    if (!_isSupportedPlatform) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Scanner is available on Android and iOS devices.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
        ),
      );
    } else if (_isInitializing) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Starting camera…',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    } else if (!_isScannerReady) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_outlined,
                size: 34,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 10),
              Text(
                _scannerError ?? 'Scanner is not available right now.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _initializeScanner,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
              if (_permissionPermanentlyDenied) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openAppSettings(),
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      body = Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes.isNotEmpty
                  ? capture.barcodes.first.rawValue
                  : null;
              if (code == null) return;
              _handleCode(code);
            },
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => _controller.toggleTorch(),
                  icon: const Icon(Icons.flashlight_on_rounded),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: () => _controller.switchCamera(),
                  icon: const Icon(Icons.cameraswitch_rounded),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Scan a paper QR / barcode to open the document instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Scan Paper'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
    );
  }
}
