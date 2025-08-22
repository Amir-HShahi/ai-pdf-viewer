import 'package:shared_preferences/shared_preferences.dart';

class PdfStatePersistenceService {
  static const _keyPdfPath = 'last_pdf_path';
  static const _keyPdfPage = 'last_pdf_page';

  Future<void> savePdfState(String path, int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPdfPath, path);
    await prefs.setInt(_keyPdfPage, page);
  }

  Future<Map<String, dynamic>?> getLastPdfState() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyPdfPath);
    final page = prefs.getInt(_keyPdfPage);

    if (path != null && page != null) {
      return {'path': path, 'page': page};
    }
    return null;
  }

  Future<void> clearSavedPdf() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPdfPath);
    await prefs.remove(_keyPdfPage);
  }
}
