import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';

class UIHelpers {
  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.blackTransparent03,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.whiteTransparent02),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static BoxDecoration getGlassmorphicDecoration({
    Color? backgroundColor,
    Color? borderColor,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.whiteTransparent01,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor ?? AppColors.whiteTransparent02),
      boxShadow: const [
        BoxShadow(
          color: AppColors.blackTransparent02,
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  static Widget buildGlassmorphicContainer({
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
    double borderRadius = 16,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: getGlassmorphicDecoration(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
