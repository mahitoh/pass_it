import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/app_state.dart';
import '../data/upload_pipeline.dart';
import '../data/supabase_backend.dart';

class UploadWorkflowPage extends StatefulWidget {
  const UploadWorkflowPage({super.key});

  @override
  State<UploadWorkflowPage> createState() => _UploadWorkflowPageState();
}

class _UploadWorkflowPageState extends State<UploadWorkflowPage> {
  final PageController _pageController = PageController();
  final UploadPipeline _uploadPipeline = UploadPipeline();

  int _currentStep = 0;
  bool _isUploading = false;
  double _uploadProgress = 0;
  String _uploadStage = 'Waiting for a file';
  String? _errorMessage;
  PlatformFile? _selectedFile;

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
    super.dispose();
  }

  Future<void> _goNext() async {
    final next = _currentStep + 1;
    if (next < 5) {
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
        withData: false,
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

  Future<void> _submitContribution() async {
    if (_selectedFile?.path == null) {
      setState(() => _errorMessage = 'Choose a file before submitting.');
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
          sourcePath: _selectedFile!.path!,
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
              'Step ${_currentStep + 1} of 5',
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
          child: _ProgressBar(current: _currentStep, total: 5),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentStep = i),
        children: [
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

  const _FileAndReviewStep({
    required this.autoTitle,
    required this.selectedFile,
    required this.isUploading,
    required this.uploadProgress,
    required this.uploadStage,
    required this.errorMessage,
    required this.onPickFile,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasFile = selectedFile != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload File',
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the PDF or image of the past paper.',
            style: GoogleFonts.inter(fontSize: 14, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

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
          ),

          const SizedBox(height: 24),

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
                value: uploadProgress,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              uploadStage,
              style: GoogleFonts.inter(
                fontSize: 12,
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
