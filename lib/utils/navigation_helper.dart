import 'package:flutter/cupertino.dart';
import 'package:pdfrx/pdfrx.dart';

class NavigationHelper {
  static Future<void> goToPage(
    PdfViewerController controller,
    int pageNumber,
    Function(String) showError,
  ) async {
    try {
      debugPrint('Attempting to go to page: $pageNumber');
      await controller.goToPage(pageNumber: pageNumber);
      await Future.delayed(const Duration(milliseconds: 100));
      controller.isReady;
      await controller.goToPage(pageNumber: pageNumber);
      debugPrint('Navigation completed for page: $pageNumber');
    } catch (e) {
      debugPrint('Error navigating to page $pageNumber: $e');
      showError('Failed to navigate to page $pageNumber');
    }
  }
}
