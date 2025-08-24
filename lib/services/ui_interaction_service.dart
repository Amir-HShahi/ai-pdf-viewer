import 'package:ai_pdf_viewer/services/token_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_colors.dart';
import '../utils/ui_helpers.dart';
import '../view/page_jump_dialog.dart';
import '../view/summary.dart';

class UiInteractionService {
  final TokenStorageService _tokenStorage = TokenStorageService();

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

  Future<void> showApiTokenSettingsDialog(BuildContext context) async {
    final TextEditingController tokenController = TextEditingController();
    final TextEditingController baseUrlController = TextEditingController();

    // Load current values
    final currentToken = await _tokenStorage.getApiToken();
    final currentBaseUrl = await _tokenStorage.getBaseUrl();

    tokenController.text = currentToken ?? '';
    baseUrlController.text = currentBaseUrl ?? '';

    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: UIHelpers.buildGlassmorphicContainer(
            backgroundColor: AppColors.blackTransparent03,
            borderRadius: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  const Text(
                    'API Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // API Token Field
                  const Text(
                    'API Token',
                    style: TextStyle(
                      color: AppColors.whiteTransparent08,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: tokenController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter your API token',
                      hintStyle: TextStyle(
                        color: AppColors.whiteTransparent005,
                      ),
                      filled: true,
                      fillColor: AppColors.blackTransparent02,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.whiteTransparent03,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info text
                  Text(
                    'Your API token will be stored securely on this device and used for summarization requests.',
                    style: TextStyle(
                      color: AppColors.whiteTransparent01,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      // Clear Button
                      Expanded(
                        child: TextButton(
                          onPressed: () async {
                            await _tokenStorage.clearAll();
                            tokenController.clear();
                            baseUrlController.clear();
                            if (context.mounted) {
                              UIHelpers.showSnackBar(
                                context,
                                'Settings cleared',
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.blackTransparent02,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Clear',
                            style: TextStyle(
                              color: AppColors.whiteTransparent07,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Cancel Button
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.blackTransparent02,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.whiteTransparent07,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Save Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final token = tokenController.text.trim();
                            final baseUrl = baseUrlController.text.trim();

                            if (token.isNotEmpty) {
                              await _tokenStorage.saveApiToken(token);
                            }

                            if (baseUrl.isNotEmpty) {
                              await _tokenStorage.saveBaseUrl(baseUrl);
                            }

                            if (context.mounted) {
                              Navigator.of(context).pop();
                              UIHelpers.showSnackBar(
                                context,
                                'Settings saved successfully',
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.whiteTransparent02,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
