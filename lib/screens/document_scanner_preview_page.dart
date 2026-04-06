import 'dart:io';

import 'package:flutter/material.dart';

import '../data/document_scanner_service.dart';

class DocumentScannerPreviewPage extends StatefulWidget {
  final List<String> imagePaths;

  const DocumentScannerPreviewPage({super.key, required this.imagePaths});

  @override
  State<DocumentScannerPreviewPage> createState() =>
      _DocumentScannerPreviewPageState();
}

class _DocumentScannerPreviewPageState
    extends State<DocumentScannerPreviewPage> {
  final DocumentScannerService _scannerService = DocumentScannerService();
  late final PageController _pageController;
  late final List<File> _scannedImages;
  int _currentPageIndex = 0;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _scannedImages = widget.imagePaths.map(File.new).toList();
  }

  Future<void> _generatePdf() async {
    if (_scannedImages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pages to scan. Please scan at least one page.'),
        ),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdfFile = await _scannerService.combineScansToPdf(
        _scannedImages.map((file) => file.path).toList(),
      );

      if (!mounted) return;

      Navigator.pop(context, pdfFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _deletePage(int index) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text('Remove page ${index + 1} from the scan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _scannedImages.removeAt(index);
                if (_currentPageIndex >= _scannedImages.length &&
                    _currentPageIndex > 0) {
                  _currentPageIndex--;
                }
                if (_scannedImages.isNotEmpty) {
                  _pageController.jumpToPage(
                    _currentPageIndex.clamp(0, _scannedImages.length - 1),
                  );
                }
              });
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _scanMorePages() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Scanned Document'),
        elevation: 0,
      ),
      body: _scannedImages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  const Text('No scanned images found'),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.grey[900],
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentPageIndex = index);
                      },
                      itemCount: _scannedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _scannedImages[index],
                              fit: BoxFit.contain,
                            ),
                            Positioned(
                              top: 16,
                              right: 16,
                              child: FloatingActionButton.small(
                                onPressed: () => _deletePage(index),
                                backgroundColor: Colors.red,
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Page ${_currentPageIndex + 1} of ${_scannedImages.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_scannedImages.length} ${_scannedImages.length == 1 ? 'page' : 'pages'}',
                          style: TextStyle(
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isGeneratingPdf ? null : _generatePdf,
                          icon: _isGeneratingPdf
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.blue[700],
                                    ),
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(
                            _isGeneratingPdf
                                ? 'Generating PDF...'
                                : 'Generate PDF',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _scanMorePages,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Scan More Pages'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}
