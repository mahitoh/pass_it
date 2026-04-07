import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<dynamic>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _refreshConnectivity();
    _subscription = Connectivity().onConnectivityChanged.listen(
      (result) => _setOfflineFromResult(result),
    );
  }

  Future<void> _refreshConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _setOfflineFromResult(result);
  }

  void _setOfflineFromResult(dynamic result) {
    var nextOffline = false;

    if (result is ConnectivityResult) {
      nextOffline = result == ConnectivityResult.none;
    } else if (result is List<ConnectivityResult>) {
      nextOffline =
          result.isEmpty ||
          result.every((entry) => entry == ConnectivityResult.none);
    }

    if (!mounted || nextOffline == _offline) return;
    setState(() => _offline = nextOffline);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _offline ? 36 : 0,
          color: const Color(0xFFB07800),
          child: _offline
              ? Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "You're offline - showing cached papers",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
