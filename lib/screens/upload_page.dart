import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/app_state.dart';
import '../data/upload_pipeline.dart';
import '../data/supabase_backend.dart';
import '../data/document_scanner_service.dart';
import 'document_scanner_preview_page.dart';

class UploadWorkflowPage extends StatefulWidget {
  const UploadWorkflowPage({super.key});

  @override
  State<UploadWorkflowPage> createState() => _UploadWorkflowPageState();
}

class _UploadWorkflowPageState extends State<UploadWorkflowPage> {
  final PageController _pageController = PageController();
  final UploadPipeline _uploadPipeline = UploadPipeline();
  final DocumentScannerService _scannerService = DocumentScannerService();

  int _currentStep = 0;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadStage = 'Waiting for a file';
  String? _errorMessage;
  PlatformFile? _selectedFile;
  bool _scannerAvailable = Platform.isAndroid || Platform.isIOS;

  // Scanner mode: 'upload', 'scan', or null (not selected)
  String? _uploadMode;

  String _selectedLevel = 'University';
  String _selectedInstitution = 'University of Buea';
  String _selectedCourse = 'Engineering Math';
  late int _selectedYear;

  final List<String> _levels = const [
    'University',
    'High School',
    'Professional',
    'Competitive',
  ];

  static const _universityInstitutions = [
    'University of Buea',
    'University of Yaoundé I',
    'University of Yaoundé II',
    'University of Douala',
    'University of Dschang',
    'University of Bamenda',
    'University of Ngaoundéré',
    'University of Maroua',
    'ENSP Yaoundé',
    'Polytech Yaoundé',
    'EGTC Bamenda',
    'ICT University',
  ];

  static const _highSchoolInstitutions = [
    'GCE Board (Anglophone)',
    'Ministry of Education (Francophone)',
    'GBHS Yaoundé',
    'Bilingual Grammar School',
  ];

  static const _competitiveInstitutions = [
    'ENAM',
    'FMBS',
    'IRIC',
    'Police Academy',
    'Military Academy',
    'ENS Yaoundé',
    'ENSET Kumba',
  ];

  static const _universityCourses = [
    'Engineering Mathematics',
    'Data Structures & Algorithms',
    'Operating Systems',
    'Database Systems',
    'Computer Networks',
    'Software Engineering',
    'Linear Algebra',
    'Organic Chemistry',
    'Micro-economics',
    'Constitutional Law',
    'Anatomy & Physiology',
    'Financial Accounting',
  ];

  static const _highSchoolCourses = [
    'Mathematics (Series C)',
    'Mathematics (Series D)',
    'Mathematics (Series A)',
    'Physics/Chemistry (Series C)',
    'Biology/Chemistry (Series D)',
    'French Language',
    'English Language',
    'History & Geography',
    'Computer Science',
    'Economics',
    'Philosophy',
  ];

  static const _competitiveCourses = [
    'Administrative Law',
    'General Culture',
    'French Language',
    'English Language',
    'Logic & Reasoning',
    'Mathematics',
    'Civic Education',
  ];

  List<String> get _institutions => switch (_selectedLevel) {
    'High School' => _highSchoolInstitutions,
    'Competitive' => _competitiveInstitutions,
    _ => _universityInstitutions,
  };

  List<String> get _courses => switch (_selectedLevel) {
    'High School' => _highSchoolCourses,
    'Competitive' => _competitiveCourses,
    _ => _universityCourses,
  };

  List<int> get _years {
    final current = DateTime.now().year;
    return List.generate(12, (i) => current - i);
  }

  String get _autoTitle =>
      '$_selectedInstitution · $_selectedCourse · $_selectedYear';

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _selectedInstitution = _institutions.first;
    _selectedCourse = _courses.first;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    final next = _currentStep + 1;
    if (next < 6) {
      await _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _goBack() async {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }
    await _pageController.animateToPage(
      _currentStep - 1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _advance({
    String? level,
    String? institution,
    String? course,
    int? year,
  }) async {
    setState(() {
      if (level != null) {
        _selectedLevel = level;
        _selectedInstitution = _institutions.first;
        _selectedCourse = _courses.first;
      }
      if (institution != null) _selectedInstitution = institution;
      if (course != null) _selectedCourse = course;
      if (year != null) _selectedYear = year;
      _errorMessage = null;
    });
    await _goNext();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      setState(() {
        _selectedFile = result.files.single;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Could not open file picker: $e');
    }
  }

  Future<String?> _ensureLocalFilePath(PlatformFile file) async {
    if (file.path != null && file.path!.isNotEmpty) {
      return file.path;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final appDir = await getApplicationCacheDirectory();
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final fallbackPath =
        '${appDir.path}/picked_${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final outFile = File(fallbackPath);
    await outFile.writeAsBytes(bytes, flush: true);
    return outFile.path;
  }

  Future<void> _scanDocument() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (mounted) {
          setState(
            () => _errorMessage =
                'Document scanning is only available on Android and iOS. Use file upload on this device.',
          );
        }
        return;
      }

      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          setState(
            () => _errorMessage =
                'Camera permission is required to scan documents.',
          );
        }
        return;
      }

      debugPrint('[Upload] Starting document scan...');

      if (!mounted) return;

      // Initialize and launch scanner
      final scanResult = await _scannerService.scanDocument();

      if (scanResult == null || (scanResult.images?.isEmpty ?? true)) {
        if (mounted) {
          setState(() => _errorMessage = 'No pages scanned. Please try again.');
        }
        return;
      }

      debugPrint(
        '[Upload] Scan completed with ${(scanResult.images?.length ?? 0)} pages',
      );

      if (!mounted) return;

      // Extract image paths from the scan result
      final imagePaths = _scannerService.extractImagePaths(scanResult);

      if (imagePaths.isEmpty) {
        if (mounted) {
          setState(
            () => _errorMessage =
                'Failed to extract scanned images. Please try again.',
          );
        }
        return;
      }

      // Show preview page
      final pdfFile = await Navigator.push<File>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DocumentScannerPreviewPage(imagePaths: imagePaths),
        ),
      );

      if (pdfFile != null && mounted) {
        debugPrint('[Upload] PDF generated: ${pdfFile.path}');
        // Convert File to PlatformFile
        final fileName =
            'scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
        setState(() {
          _selectedFile = PlatformFile(
            name: fileName,
            path: pdfFile.path,
            size: pdfFile.lengthSync(),
            identifier: pdfFile.path,
          );
          _errorMessage = null;
          _uploadMode = 'scan';
        });
        // Move to metadata selection steps
        await _goNext();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString();
        setState(() {
          _errorMessage = 'Error scanning document: $message';
          if (message.contains('Document scanner is not available')) {
            _scannerAvailable = false;
          }
        });
      }
      debugPrint('[Upload] Scan error: $e');
    }
  }

  Future<void> _selectUploadMode(String mode) async {
    setState(() => _uploadMode = mode);

    if (mode == 'scan') {
      await _scanDocument();
    } else if (mode == 'upload') {
      await _goNext();
    }
  }

  Future<void> _submitContribution() async {
    if (_selectedFile == null) {
      setState(() => _errorMessage = 'Choose a file before submitting.');
      return;
    }

    final sourcePath = await _ensureLocalFilePath(_selectedFile!);
    if (sourcePath == null) {
      setState(
        () => _errorMessage =
            'Could not access the selected file. Please pick it again.',
      );
      return;
    }

    final appState = AppStateScope.of(context);
    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadStage = 'Starting upload…';
      _errorMessage = null;
    });
    try {
      await _uploadPipeline.submit(
        submission: UploadSubmission(
          level: _selectedLevel,
          institution: _selectedInstitution,
          course: _selectedCourse,
          year: _selectedYear,
          fileName: _selectedFile!.name,
          sourcePath: sourcePath,
        ),
        appState: appState,
        supabaseBackend: SupabaseBackend.instance,
        onProgress: (snapshot) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = snapshot.progress;
            _uploadStage = snapshot.stage;
          });
        },
      );
      if (!mounted) return;
      _showSuccessSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SuccessSheet(
        onDone: () {
          Navigator.pop(ctx);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            _currentStep == 0 ? Icons.close : Icons.arrow_back_rounded,
            color: cs.onSurface,
          ),
          onPressed: _goBack,
        ),
        title: Column(
          children: [
            Text(
              'Upload Paper',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            Text(
              'Step ${_currentStep + 1} of 6',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _ProgressBar(current: _currentStep, total: 6),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentStep = i),
        children: [
          // Step 0: Select upload mode (Scan or Upload)
          _UploadModeSelectionStep(
            onSelectScan: () => _selectUploadMode('scan'),
            onSelectUpload: () => _selectUploadMode('upload'),
            scannerAvailable: _scannerAvailable,
            errorMessage: _uploadMode == null ? _errorMessage : null,
          ),
          _SelectionStep(
            title: 'Select Level',
            subtitle: 'What type of exam is this paper from?',
            options: _levels,
            selected: _selectedLevel,
            iconFor: _levelIcon,
            onSelect: (v) => _advance(level: v),
          ),
          _SelectionStep(
            title: 'Select Institution',
            subtitle: 'Which school or board set this paper?',
            options: _institutions,
            selected: _selectedInstitution,
            onSelect: (v) => _advance(institution: v),
          ),
          _SelectionStep(
            title: 'Select Course',
            subtitle: 'Which course or subject is this?',
            options: _courses,
            selected: _selectedCourse,
            onSelect: (v) => _advance(course: v),
          ),
          _YearStep(
            years: _years,
            selected: _selectedYear,
            onSelect: (v) => _advance(year: v),
          ),
          _FileAndReviewStep(
            autoTitle: _autoTitle,
            selectedFile: _selectedFile,
            isUploading: _isUploading,
            uploadProgress: _uploadProgress,
            uploadStage: _uploadStage,
            errorMessage: _errorMessage,
            onPickFile: _pickFile,
            onSubmit: _submitContribution,
            uploadMode: _uploadMode,
          ),
        ],
      ),
    );
  }

  IconData _levelIcon(String level) => switch (level) {
    'University' => Icons.account_balance_rounded,
    'High School' => Icons.school_rounded,
    'Professional' => Icons.work_rounded,
    'Competitive' => Icons.emoji_events_rounded,
    _ => Icons.description_rounded,
  };
}

class _UploadModeSelectionStep extends StatelessWidget {
  final VoidCallback onSelectScan;
  final VoidCallback onSelectUpload;
  final bool scannerAvailable;
  final String? errorMessage;

  const _UploadModeSelectionStep({
    required this.onSelectScan,
    required this.onSelectUpload,
    required this.scannerAvailable,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How do you want to submit?',
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose between uploading an existing file or scanning a new document.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // Scan option
            GestureDetector(
              onTap: scannerAvailable ? onSelectScan : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scannerAvailable
                      ? cs.surfaceContainerLowest
                      : cs.surfaceContainerHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scannerAvailable
                        ? cs.outlineVariant.withValues(alpha: 0.3)
                        : cs.outlineVariant.withValues(alpha: 0.18),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 24,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Scan Document',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: scannerAvailable
                            ? cs.onSurface
                            : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      scannerAvailable
                          ? 'Use your camera to scan and upload a document. Multi-page support with PDF generation.'
                          : 'Scanner unavailable in this runtime. Use file upload instead.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scannerAvailable
                            ? cs.onSurfaceVariant
                            : cs.error,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: scannerAvailable
                                    ? cs.primary
                                    : cs.outlineVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Multi-page',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: scannerAvailable
                                      ? cs.onSurfaceVariant
                                      : cs.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: scannerAvailable
                                    ? cs.primary
                                    : cs.outlineVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Edge detection',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: scannerAvailable
                                      ? cs.onSurfaceVariant
                                      : cs.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Upload option
            GestureDetector(
              onTap: onSelectUpload,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.upload_file_rounded,
                        size: 24,
                        color: cs.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload File',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose a PDF or image from your device to upload.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: cs.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PDF, JPG, PNG',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: cs.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Max 20 MB',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: cs.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.inter(fontSize: 13, color: cs.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(total, (i) {
        final done = i <= current;
        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
            decoration: BoxDecoration(
              color: done
                  ? cs.primary
                  : cs.outlineVariant.withValues(alpha: 0.3),
              borderRadius: i == 0
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      bottomLeft: Radius.circular(2),
                    )
                  : i == total - 1
                  ? const BorderRadius.only(
                      topRight: Radius.circular(2),
                      bottomRight: Radius.circular(2),
                    )
                  : BorderRadius.zero,
            ),
          ),
        );
      }),
    );
  }
}

class _SelectionStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final IconData Function(String)? iconFor;

  const _SelectionStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.iconFor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: options.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final opt = options[i];
              final isSelected = opt == selected;
              return GestureDetector(
                onTap: () => onSelect(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cs.primary.withValues(alpha: 0.08)
                        : cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? cs.primary
                          : cs.outlineVariant.withValues(alpha: 0.25),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (iconFor != null) ...[
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.primary.withValues(alpha: 0.12)
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            iconFor!(opt),
                            size: 18,
                            color: isSelected
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Text(
                          opt,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isSelected ? cs.primary : cs.outlineVariant,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _YearStep extends StatelessWidget {
  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelect;

  const _YearStep({
    required this.years,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Date',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When was this paper written?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: cs.copyWith(
                        primary: cs.primary,
                        onPrimary: Colors.white,
                        surface: cs.surfaceContainerLowest,
                        onSurface: cs.onSurface,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: DateTime(selected),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      onDateChanged: (date) {
                        onSelect(date.year);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FileAndReviewStep extends StatelessWidget {
  final String autoTitle;
  final PlatformFile? selectedFile;
  final bool isUploading;
  final double uploadProgress;
  final String uploadStage;
  final String? errorMessage;
  final VoidCallback onPickFile;
  final VoidCallback onSubmit;
  final String? uploadMode;

  const _FileAndReviewStep({
    required this.autoTitle,
    required this.selectedFile,
    required this.isUploading,
    required this.uploadProgress,
    required this.uploadStage,
    required this.errorMessage,
    required this.onPickFile,
    required this.onSubmit,
    required this.uploadMode,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFile = selectedFile != null;
    final normalizedProgress = uploadProgress.clamp(0.0, 1.0).toDouble();
    final progressPercent = (normalizedProgress * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            uploadMode == 'scan' ? 'Review Scanned Document' : 'Upload File',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            uploadMode == 'scan'
                ? 'Your scanned PDF is ready. Review the details below.'
                : 'Choose the PDF or image of the past paper.',
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          if (uploadMode != 'scan')
            GestureDetector(
              onTap: isUploading ? null : onPickFile,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: hasFile
                      ? cs.primary.withValues(alpha: 0.06)
                      : cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasFile
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.3),
                    width: hasFile ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: hasFile
                            ? cs.primary.withValues(alpha: 0.12)
                            : cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        hasFile
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_outlined,
                        size: 26,
                        color: hasFile ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasFile ? selectedFile!.name : 'Tap to choose a file',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: hasFile ? cs.primary : cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile
                          ? '${(selectedFile!.size / 1024).round()} KB · Ready'
                          : 'PDF, JPG, PNG · Max 20 MB',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary, width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 26,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selectedFile!.name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(selectedFile!.size / 1024).round()} KB · Ready to upload',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.stars_rounded, size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earn +50 points',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You\'ll receive points once your paper is approved',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_fix_high_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-generated title',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        autoTitle,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (isUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: normalizedProgress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    uploadStage,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '$progressPercent%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$progressPercent% uploaded',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: cs.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: GoogleFonts.inter(fontSize: 13, color: cs.error),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isUploading || !hasFile ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: cs.surfaceContainerHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(isUploading ? uploadStage : 'Submit Paper'),
            ),
          ),

          const SizedBox(height: 16),

          _Guidelines(),
        ],
      ),
    );
  }
}

class _Guidelines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const items = [
      'Upload only genuine past exam papers',
      'Ensure scans are clear and fully readable',
      'Do not upload textbooks or copyrighted material',
      'Incorrect metadata will cause removal',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Guidelines',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: cs.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      g,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessSheet({required this.onDone});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: cs.secondary,
              size: 44,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Paper Uploaded!',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your paper is under review. You\'ll earn 50 pts once it\'s approved.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Back to Home',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
