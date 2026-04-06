import 'dart:async';
import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/models/paper_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/paper_providers.dart';
import '../../../../shared/widgets/custom_stepper.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../shared/widgets/upload_progress_sheet.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  int _currentStep = 0;
  final _pageController = PageController();
  String? _selectedFilePath;
  String? _selectedFileName;
  final _courseCodeController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _instructorController = TextEditingController();
  String _courseCode = '';
  String _courseName = '';
  int? _selectedYear;
  String _semester = 'Fall';
  AssessmentType _assessmentType = AssessmentType.finalExam;
  String _instructor = '';
  bool _addUploaderName = true;

  final _courseMap = const {
    'CS201': 'Data Structures',
    'CS301': 'Operating Systems',
    'MTH211': 'Linear Algebra',
    'PHY101': 'General Physics',
  };

  @override
  void dispose() {
    _pageController.dispose();
    _courseCodeController.dispose();
    _courseNameController.dispose();
    _instructorController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() => _currentStep--);
    }
  }

  bool get _isStep1Valid => _selectedFilePath != null;
  bool get _isStep2Valid =>
      _courseCode.isNotEmpty && _courseName.isNotEmpty && _selectedYear != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            CustomStepper(
              currentStep: _currentStep,
              steps: const ['Source', 'Metadata', 'Attribution'],
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                ],
              ),
            ),
            _buildFooterControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (_currentStep > 0)
            PressableScale(
              onTap: _prevStep,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(LucideIcons.chevronLeft,
                    size: 18, color: Colors.white),
              ),
            )
          else
            const SizedBox(width: 40, height: 40),
          const Spacer(),
          Text('Upload Paper',
              style: Theme.of(context)
                  .textTheme
                  .displaySmall
                  ?.copyWith(fontSize: 18)),
          const Spacer(),
          const SizedBox(width: 40, height: 40),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Source',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('Upload a file or scan a paper to begin.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: PressableScale(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(16),
                  child: const _SourceCard(
                    title: 'Upload File',
                    subtitle: 'PDF, DOC, TXT',
                    icon: LucideIcons.upload,
                    accentColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: PressableScale(
                  onTap: _scanPaper,
                  borderRadius: BorderRadius.circular(16),
                  child: const _SourceCard(
                    title: 'Scan Paper',
                    subtitle: 'Use camera',
                    icon: LucideIcons.camera,
                    accentColor: AppColors.quiz,
                  ),
                ),
              ),
            ],
          ),
          if (_selectedFilePath != null) ...[
            const SizedBox(height: 24),
            _buildPreviewCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final ext = _selectedFilePath!.split('.').last.toLowerCase();
    final isImage = ext == 'png' || ext == 'jpg' || ext == 'jpeg';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(_selectedFilePath!),
                        fit: BoxFit.cover),
                  )
                : const Icon(LucideIcons.fileText,
                    size: 32, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? 'Selected file',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ready to upload',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paper Metadata',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('Tell students what this paper covers.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          _InputField(
            label: 'Course Code',
            hintText: 'e.g. CS201',
            controller: _courseCodeController,
            onChanged: (value) {
              setState(() {
                _courseCode = value.toUpperCase();
                final mapped = _courseMap[_courseCode];
                if (mapped != null) {
                  _courseName = mapped;
                  _courseNameController.text = mapped;
                }
              });
            },
          ),
          if (_courseCode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _courseMap.keys
                  .where((code) => code.startsWith(_courseCode))
                  .map((code) => InkWell(
                        onTap: () {
                          setState(() {
                            _courseCode = code;
                            _courseName = _courseMap[code]!;
                            _courseCodeController.text = code;
                            _courseNameController.text = _courseName;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child:
                              Text(code, style: const TextStyle(fontSize: 12)),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          _InputField(
            label: 'Course Name',
            hintText: 'Auto-filled from code',
            controller: _courseNameController,
            onChanged: (value) => setState(() => _courseName = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildYearDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildSemesterToggle()),
            ],
          ),
          const SizedBox(height: 16),
          Text('Assessment Type',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: AssessmentType.values.map((type) {
              final isActive = _assessmentType == type;
              return PressableScale(
                onTap: () => setState(() => _assessmentType = type),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color:
                            isActive ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    _labelForType(type),
                    style: TextStyle(
                      color:
                          isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Attribution',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 8),
          Text('Credit the instructor and preview your upload.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          _InputField(
            label: 'Instructor Name',
            hintText: 'Search instructor',
            controller: _instructorController,
            onChanged: (value) => setState(() => _instructor = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Dr. Foka', 'Dr. Hassan', 'Prof. Ade', 'Dr. Chen']
                .map((name) => InkWell(
                      onTap: () {
                        setState(() => _instructor = name);
                        _instructorController.text = name;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child:
                            Text(name, style: const TextStyle(fontSize: 12)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Add your name as uploader',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        'Reward yourself with scholar points',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _addUploaderName,
                  onChanged: (value) =>
                      setState(() => _addUploaderName = value),
                  activeThumbColor: AppColors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPreviewSummary(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isStep2Valid ? _startUpload : null,
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text('Upload Paper'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterControls() {
    final canProceed = _currentStep == 0
        ? _isStep1Valid
        : _currentStep == 1
            ? _isStep2Valid
            : true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (_currentStep < 2)
            Expanded(
              child: ElevatedButton(
                onPressed: canProceed ? _nextStep : null,
                child: const Text('Next'),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildYearDropdown() {
    final currentYear = DateTime.now().year;
    final years = List.generate(currentYear - 1999, (i) => currentYear - i);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          hint: const Text('Year'),
          items: years
              .map((year) => DropdownMenuItem<int>(
                    value: year,
                    child: Text(year.toString()),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedYear = value),
        ),
      ),
    );
  }

  Widget _buildSemesterToggle() {
    const semesters = ['Spring', 'Summer', 'Fall'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: semesters.map((s) {
          final isActive = _semester == s;
          return Expanded(
            child: PressableScale(
              onTap: () => setState(() => _semester = s),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  s,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPreviewSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          _summaryRow('Course', '$_courseCode - $_courseName'),
          _summaryRow('Year', _selectedYear?.toString() ?? 'N/A'),
          _summaryRow('Semester', _semester),
          _summaryRow('Type', _labelForType(_assessmentType)),
          _summaryRow('Instructor', _instructor.isEmpty ? 'N/A' : _instructor),
          _summaryRow('Uploader', _addUploaderName ? 'You' : 'Anonymous'),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(
              child: Text(value,
                  style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }

  String _labelForType(AssessmentType type) {
    switch (type) {
      case AssessmentType.ca:
        return 'CA';
      case AssessmentType.quiz:
        return 'Quiz';
      case AssessmentType.midterm:
        return 'Mid-term';
      case AssessmentType.finalExam:
        return 'Final Exam';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _scanPaper() async {
    final images = await CunningDocumentScanner.getPictures(noOfPages: 1);
    if (images != null && images.isNotEmpty) {
      setState(() {
        _selectedFilePath = images.first;
        _selectedFileName = 'Scanned Paper';
      });
    }
  }

  Future<void> _startUpload() async {
    double progress = 0.0;
    UploadState state = UploadState.inProgress;
    StateSetter? setModalState;

    final newPaper = Paper(
      id: 'paper_${DateTime.now().millisecondsSinceEpoch}',
      courseCode: _courseCode,
      courseName: _courseName,
      instructor: _instructor,
      type: _assessmentType,
      year: _selectedYear!,
      semester: _semester,
      fileUrl: _selectedFilePath ?? '',
      uploaderId: _addUploaderName ? 'local-user' : 'anonymous',
      uploadedAt: DateTime.now(),
    );

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            setModalState = modalSetState;
            return UploadProgressSheet(state: state, progress: progress);
          },
        );
      },
    );

    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      progress += 0.18;
      if (progress >= 1.0) {
        timer.cancel();
        state = UploadState.success;
        setModalState?.call(() {});
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            ref
                .read(paperRepositoryProvider)
                .uploadPaper(newPaper, newPaper.fileUrl);
            ref.invalidate(recentPapersProvider);
            Navigator.pop(context);
          }
        });
      } else {
        setModalState?.call(() {});
      }
    });
  }
}

class _SourceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _SourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: accentColor),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _InputField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              border: InputBorder.none,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
