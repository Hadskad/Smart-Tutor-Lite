import 'package:flutter/material.dart';

/// Centralized color constants for the Smart Tutor app.
///
/// Use these colors consistently across all pages and widgets
/// instead of defining local color constants.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // --- Dark Theme Colors (Primary palette for most screens) ---

  /// Main background color for dark screens
  static const Color background = Color(0xFF1E1E1E);

  /// Card background color
  static const Color card = Color(0xFF333333);

  /// Vibrant electric blue - primary accent
  static const Color accentBlue = Color(0xFF00BFFF);

  /// Soft coral/orange - secondary accent
  static const Color accentCoral = Color(0xFFFF7043);

  /// Pure white for text and icons
  static const Color white = Colors.white;

  /// Light gray for secondary text
  static const Color lightGray = Color(0xFFCCCCCC);

  /// Dark gray for disabled/tertiary text
  static const Color darkGray = Color(0xFF888888);

  // --- Status Colors ---

  /// Success green
  static const Color success = Color(0xFF4CAF50);

  /// Warning amber
  static const Color warning = Color(0xFFFFC107);

  /// Error red
  static const Color error = Color(0xFFEF4444);

  // --- Material Type Colors (for folder content badges) ---

  /// Transcription/Notes color
  static const Color materialNotes = Color(0xFF4FC3F7);

  /// Summary color
  static const Color materialSummary = Color(0xFF81C784);

  /// Quiz color
  static const Color materialQuiz = Color(0xFFFFB74D);

  /// Flashcard color
  static const Color materialFlashcard = Color(0xFFBA68C8);

  /// Audio/TTS color
  static const Color materialAudio = Color(0xFFE57373);

  // --- Opacity Helpers ---

  /// Returns the color with the specified opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}

