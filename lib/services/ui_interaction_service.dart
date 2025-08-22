import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/ui_helpers.dart';
import '../view/page_jump_dialog.dart';
import '../view/summary.dart';

class UiInteractionService {
  void showSummaryScreen(BuildContext context, String text) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => Summary(text: text)));
  }

  void copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    UIHelpers.showSnackBar(context, 'Text copied to clipboard');
  }

  Future<int?> showPageJumpDialog(BuildContext context, int totalPages) async {
    final pageController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierColor: AppColors.blackTransparent03,
      builder:
          (context) => PageJumpDialog(
        totalPages: totalPages,
        controller: pageController,
      ),
    );

    pageController.dispose();

    if (result != null && result.isNotEmpty) {
      return int.tryParse(result);
    }
    return null;
  }
}