import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/ui_helpers.dart';

class PageJumpDialog extends StatelessWidget {
  final int totalPages;
  final TextEditingController controller;

  const PageJumpDialog({
    super.key,
    required this.totalPages,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: UIHelpers.buildGlassmorphicContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Go to Page',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Enter page number (1 - $totalPages):',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(context),
            const SizedBox(height: 16),
            _buildActionButtons(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        autofocus: true,
        onSubmitted: (value) => Navigator.pop(context, value),
        decoration: InputDecoration(
          labelText: 'Page number',
          labelStyle: const TextStyle(
            color: AppColors.whiteTransparent08,
            fontWeight: FontWeight.w600,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.whiteTransparent02),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.whiteTransparent04),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: AppColors.whiteTransparent005,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildDialogButton('Cancel', () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _buildDialogButton(
            'Go',
            () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogButton(String text, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: AppColors.whiteTransparent01,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.whiteTransparent02),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
