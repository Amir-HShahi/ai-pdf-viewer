import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (!context.mounted) return null;

    try {
      final result = await showDialog<int>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          return PageJumpDialog(totalPages: totalPages);
        },
      );

      return result;
    } catch (e) {
      debugPrint('Error showing page jump dialog: $e');
      return null;
    }
  }
}
