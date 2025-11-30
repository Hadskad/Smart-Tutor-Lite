import 'package:flutter/material.dart';

class AppTheme {
  // Modern Indigo Palette
  static const _primary = Color(0xFF4F46E5); // Indigo 600
  static const _secondary = Color(0xFF0D9488); // Teal 600
  static const _tertiary = Color(0xFFF59E0B); // Amber 500
  static const _error = Color(0xFFEF4444); // Red 500
  
  // Backgrounds
  static const _background = Color(0xFFF9FAFB); // Cool Gray 50
  static const _surface = Colors.white;

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto', // Falls back to system default if not found
      
      // Color System
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        tertiary: _tertiary,
        error: _error,
        surface: _surface,
        brightness: Brightness.light,
      ),
      
      scaffoldBackgroundColor: _background,
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Typography (Modern & Readable)
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32, 
          fontWeight: FontWeight.bold, 
          color: Colors.black87,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24, 
          fontWeight: FontWeight.w600, 
          color: Colors.black87,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20, 
          fontWeight: FontWeight.w600, 
          color: Colors.black87,
        ),
        bodyLarge: TextStyle(
          fontSize: 16, 
          color: Colors.black87,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14, 
          color: Colors.black54,
          height: 1.5,
        ),
      ),

      // Component: AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),

      // Component: Cards
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFFE5E7EB)), // Grey 200
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // Component: Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Component: Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
      ),

      // Component: Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        elevation: 0,
        height: 64,
        indicatorColor: _primary.withValues(alpha: 0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primary);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
    );
  }
}

