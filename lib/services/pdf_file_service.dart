import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfFileService {
  Future<(String, PdfDocument)?> pickAndLoadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result?.files.single.path case final String path) {
        final document = await PdfDocument.openFile(path);
        return (path, document);
      }
    } catch (e) {
      debugPrint('Error picking PDF: $e');
      rethrow;
    }
    return null;
  }
}
