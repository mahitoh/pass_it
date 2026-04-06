import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DocumentScannerService {
  late final DocumentScanner _scanner;
  bool _isInitialized = false;

  Future<bool> initialize() async {
    try {
      _scanner = DocumentScanner(
        options: DocumentScannerOptions(
          documentFormats: {DocumentFormat.jpeg, DocumentFormat.pdf},
          pageLimit: 10,
          mode: ScannerMode.full,
          isGalleryImport: false,
        ),
      );
      _isInitialized = true;
      debugPrint('[DocumentScannerService] Scanner initialized successfully');
      return true;
    } catch (e) {
      debugPrint('[DocumentScannerService] Error initializing scanner: $e');
      return false;
    }
  }

  Future<DocumentScanningResult?> scanDocument() async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        throw 'Failed to initialize document scanner';
      }
    }

    try {
      debugPrint('[DocumentScannerService] Starting document scan...');
      final result = await _scanner.scanDocument();
      debugPrint('[DocumentScannerService] Scan completed successfully');
      return result;
    } catch (e) {
      debugPrint('[DocumentScannerService] Error scanning document: $e');
      if (e is MissingPluginException) {
        throw 'Document scanner is not available in this runtime. Fully stop and restart the app on a supported Android or iOS device, then try again.';
      }
      if (e.toString().contains('Permission denied')) {
        throw 'Camera permission denied. Please grant camera access in settings.';
      }
      if (e.toString().contains('User cancelled')) {
        throw 'Scan cancelled by user';
      }
      rethrow;
    }
  }

  List<String> extractImagePaths(DocumentScanningResult result) {
    final imagePaths = result.images ?? <String>[];
    debugPrint(
      '[DocumentScannerService] Extracted ${imagePaths.length} image paths',
    );
    return imagePaths;
  }

  Future<File> processScanImage(String imagePath) async {
    try {
      debugPrint('[DocumentScannerService] Processing scan image: $imagePath');

      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw 'Failed to decode image';
      }

      img.Image image = decodedImage;

      var quality = 90;
      while (image.width > 2400 && quality > 60) {
        image = img.copyResize(
          image,
          width: (image.width * 0.8).toInt(),
          height: (image.height * 0.8).toInt(),
        );
        quality -= 10;
      }

      final appDir = await getApplicationCacheDirectory();
      final processedPath =
          '${appDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final processedFile = File(processedPath);
      await processedFile.writeAsBytes(img.encodeJpg(image, quality: quality));

      debugPrint(
        '[DocumentScannerService] Image processed. Original: ${imageBytes.length} bytes, Processed: ${(await processedFile.length())} bytes',
      );
      return processedFile;
    } catch (e) {
      debugPrint('[DocumentScannerService] Error processing image: $e');
      rethrow;
    }
  }

  Future<File> combineScansToPdf(List<String> imagePaths) async {
    try {
      debugPrint(
        '[DocumentScannerService] Combining ${imagePaths.length} scans into PDF...',
      );

      final pdf = pw.Document();

      for (final imagePath in imagePaths) {
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          debugPrint(
            '[DocumentScannerService] Warning: Image file not found at $imagePath',
          );
          continue;
        }

        final imageBytes = await imageFile.readAsBytes();
        final decodedImage = img.decodeImage(imageBytes);
        if (decodedImage == null) {
          continue;
        }

        final aspectRatio = decodedImage.width / decodedImage.height;
        final pageWidth = PdfPageFormat.a4.width;
        final pageHeight = PdfPageFormat.a4.height;
        final fittedWidth = aspectRatio >= 1
            ? pageWidth
            : pageHeight * aspectRatio;
        final fittedHeight = aspectRatio >= 1
            ? pageWidth / aspectRatio
            : pageHeight;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Center(
                child: pw.Image(
                  pw.MemoryImage(imageBytes),
                  width: fittedWidth,
                  height: fittedHeight,
                  fit: pw.BoxFit.contain,
                ),
              );
            },
          ),
        );
      }

      final appDir = await getApplicationCacheDirectory();
      final pdfPath =
          '${appDir.path}/scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfFile = File(pdfPath);
      await pdfFile.writeAsBytes(await pdf.save());

      final fileSize = await pdfFile.length();
      debugPrint(
        '[DocumentScannerService] PDF created successfully: $pdfPath (${(fileSize / 1024).toStringAsFixed(2)} KB)',
      );

      return pdfFile;
    } catch (e) {
      debugPrint('[DocumentScannerService] Error combining scans to PDF: $e');
      rethrow;
    }
  }

  Future<void> cleanupTemporaryFiles(List<String> imagePaths) async {
    try {
      for (final path in imagePaths) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[DocumentScannerService] Deleted temporary file: $path');
        }
      }
    } catch (e) {
      debugPrint(
        '[DocumentScannerService] Error cleaning up temporary files: $e',
      );
    }
  }

  Future<void> dispose() async {
    try {
      if (_isInitialized) {
        await _scanner.close();
        _isInitialized = false;
        debugPrint('[DocumentScannerService] Scanner disposed');
      }
    } catch (e) {
      debugPrint('[DocumentScannerService] Error disposing scanner: $e');
    }
  }
}
