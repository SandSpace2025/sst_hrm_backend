import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF00B359);
  static const Color accent = Color(0xFF00B359);
  static const Color error = Color(0xFFD13438);
  static const Color warning = Color(0xFFF7630C);
  static const Color success = Color(0xFF00B359);

  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color text = Color(0xFF1F1F1F);
  static const Color textPrimary = Color(0xFF323130);
  static const Color textSecondary = Color(0xFF616161);
  static const Color textTertiary = Color(0xFF323130);
  static const Color textDisabled = Color(0xFF605E5C);

  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFEDEBE9);

  static const Color edgePrimary = primary;
  static const Color edgeSecondary = Color(0xFF00B359); // Unified to Green
  static const Color edgeAccent = accent;
  static const Color edgeError = error;
  static const Color edgeWarning = warning;
  static const Color edgeSuccess = success;
  static const Color edgeBackground = background;
  static const Color edgeSurface = surface;
  static const Color edgeText = text;
  static const Color edgeTextSecondary = textSecondary;
  static const Color edgeDivider = divider;
  static const Color edgeBorder = border;

  static const Color backgroundPrimary = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(
    0xFFF5F7FA,
  ); // Slight grey for contrast if needed
  static const Color backgroundTertiary = Color(0xFFF3F2F1);

  static const Color borderPrimary = Color(0xFFE1DFDD);
  static const Color borderSecondary = Color(0xFFC8C6C4);
  static const Color borderFocus = Color(0xFF00B359);

  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);

  // Legacy/Specific kept but updated where appropriate
  static const Color edgeBlue = Color(
    0xFF00B359,
  ); // Replaced Blue with Green for consistency
  static const Color edgeGreen = Color(0xFF00B359);
  static const Color edgeRed = Color(0xFFD13438);
  static const Color edgeOrange = Color(0xFFFF8C00);
  static const Color edgePurple = Color(0xFF5C2D91);
  static const Color edgeDarkGray = Color(0xFF323130);
  static const Color edgeMidGray = Color(0xFF605E5C);

  static const orangeColor = Color(0xFFFF9966);
  static const blueColor = Color(0xFF4A90E2);
  static const greenColor = Color(0xFF00B359);
  static const redColor = Color(0xFFFF6B6B);
  static const backgroundColor = Color(0xFFFFFFFF);

  // Constants merged from lib/core/constants/app_colors.dart
  static const Color penaltyColor = Colors.purple;
  static const Color lateColor = Colors.orange;
  static const Color successColor = Colors.green;
  static const Color errorColor = Colors.red;
  static const Color surfaceWhite = Colors.white;
  static const Color textBlack = Colors.black87;
  static const MaterialColor textGrey = Colors.grey;
}
