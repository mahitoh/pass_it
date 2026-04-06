import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:photo_view/photo_view.dart';
import '../../../../core/models/paper_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../widgets/assessment_type_chip.dart';

class PaperDetailsScreen extends StatefulWidget {
  final Paper paper;
  const PaperDetailsScreen({super.key, required this.paper});

  @override
  State<PaperDetailsScreen> createState() => _PaperDetailsScreenState();
}

class _PaperDetailsScreenState extends State<PaperDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _upvotes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _upvotes = widget.paper.upvotes;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  _buildTabBar(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildViewTab(context),
                        _buildSolutionsTab(context),
                        _buildDiscussionTab(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          PressableScale(
            onTap: () => Navigator.pop(context),
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
          ),
          const Spacer(),
          PressableScale(
            onTap: () {},
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.bookmark,
                  size: 18, color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            onTap: () {},
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.share2,
                  size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'paper-thumb-${widget.paper.id}',
            child: Container(
              width: 84,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.fileText,
                  size: 36, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.paper.courseName,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaChip(widget.paper.instructor),
                    _metaChip(widget.paper.year.toString()),
                    _metaChip(widget.paper.semester),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AssessmentTypeChip(type: widget.paper.type),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'View'),
          Tab(text: 'Solutions'),
          Tab(text: 'Discussion'),
        ],
      ),
    );
  }

  Widget _buildViewTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Expanded(child: _buildFileViewer()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(LucideIcons.download, size: 18),
                  label: const Text('Download'),
                ),
              ),
              const SizedBox(width: 12),
              PressableScale(
                onTap: () => setState(() => _upvotes += 1),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.thumbsUp,
                          size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          '$_upvotes',
                          key: ValueKey(_upvotes),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileViewer() {
    final url = widget.paper.fileUrl;
    final ext = url.split('.').last.toLowerCase();
    final isLocal = !url.startsWith('http');

    if (!isLocal) {
      return _placeholderViewer('Remote files require download.');
    }

    if (ext == 'pdf') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PDFView(
          filePath: url,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          backgroundColor: AppColors.surface,
        ),
      );
    }

    if (ext == 'png' || ext == 'jpg' || ext == 'jpeg') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: PhotoView(
          imageProvider: FileImage(File(url)),
          backgroundDecoration:
              const BoxDecoration(color: AppColors.surface),
          minScale: PhotoViewComputedScale.contained,
        ),
      );
    }

    if (ext == 'txt') {
      return _TextFileViewer(filePath: url);
    }

    // doc / docx — cannot render natively
    return _placeholderViewer(
        'DOC/DOCX preview is not supported.\nDownload to open in an external app.');
  }

  Widget _placeholderViewer(String message) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      ),
    );
  }

  Widget _buildSolutionsTab(BuildContext context) {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          itemCount: 2,
          itemBuilder: (context, index) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(LucideIcons.circleCheck,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solution by Scholar ${index + 1}',
                            style:
                                Theme.of(context).textTheme.bodyLarge),
                        const SizedBox(height: 6),
                        Text('Verified by 12 scholars',
                            style:
                                Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  PressableScale(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text('View',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: PressableScale(
            onTap: () {},
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.plus, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Add Solution',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscussionTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Scholar Name',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Does anyone have the step-by-step for question 4b?',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PressableScale(
                onTap: () {},
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.send,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
    );
  }
}

class _TextFileViewer extends StatefulWidget {
  final String filePath;
  const _TextFileViewer({required this.filePath});

  @override
  State<_TextFileViewer> createState() => _TextFileViewerState();
}

class _TextFileViewerState extends State<_TextFileViewer> {
  String? _content;

  @override
  void initState() {
    super.initState();
    File(widget.filePath).readAsString().then((text) {
      if (mounted) setState(() => _content = text);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_content == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          _content!,
          style: const TextStyle(
              color: Colors.white70, fontSize: 13, height: 1.6),
        ),
      ),
    );
  }
}
