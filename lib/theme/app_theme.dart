import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF0A3F8B);      // Deep Brand Blue
  static const Color primaryPeach = Color(0xFFEBF2FC); // Light Blue Tint
  static const Color background = Color(0xFFFAF9F8);   // Warm Light Gray/White
  static const Color darkText = Color(0xFF1C1C1E);     // Modern Dark Slate
  static const Color subtitleText = Color(0xFF8E8E93); // Slate Gray
  static const Color lightGray = Color(0xFFF2F2F7);     // Cool soft gray
  static const Color border = Color(0xFFE5E5EA);        // Input borders
  static const Color green = Color(0xFF00A896);         // Accent Green (adventure/eco)
  static const Color lightGreen = Color(0xFFE8F8F5);    // Light Green Tint
  static const Color amber = Color(0xFFFFB300);         // Rating Star yellow
  
  // Card decoration with premium shadow
  static BoxDecoration premiumCardDecoration({Color color = Colors.white, double radius = 20.0}) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(10),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Smooth custom text styles
  static const TextStyle brandLogoStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: primary,
    letterSpacing: -1.0,
  );

  static const TextStyle screenTitleStyle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: darkText,
    letterSpacing: -0.6,
  );

  static const TextStyle sectionTitleStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: darkText,
    letterSpacing: -0.5,
  );

  static const TextStyle bodyBoldStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.bold,
    color: darkText,
  );

  static const TextStyle bodyMediumStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: darkText,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: subtitleText,
  );

  // Modern input field decoration helper
  static InputDecoration inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: subtitleText, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
