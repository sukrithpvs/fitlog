// lib/core/theme/app_colors.dart
// Hevy-inspired color system with exact hex codes from spec

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Brand Accent (Electric Blue) ───
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);
  static const Color accentDark = Color(0xFF1D4ED8);

  // ─── Semantic Colors ───
  static const Color success = Color(0xFF10B981);  // PR/Completed
  static const Color warning = Color(0xFFF59E0B);  // Warm-up
  static const Color error = Color(0xFFEF4444);    // Failure/Delete
  static const Color info = Color(0xFF06B6D4);

  // ─── Set Type Badge Colors ───
  static const Color warmupBadge = Color(0xFFF59E0B);   // Amber
  static const Color dropSetBadge = Color(0xFF8B5CF6);  // Purple
  static const Color failureBadge = Color(0xFFEF4444);  // Red
  static const Color normalBadge = Color(0xFF2563EB);   // Blue

  // ─── Dark Theme (Exact Hevy Spec) ───
  static const Color darkBg = Color(0xFF121212);           // Near-black canvas
  static const Color darkSurface = Color(0xFF1C1C1E);      // Elevated cards
  static const Color darkSurfaceElevated = Color(0xFF252525);
  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);
  static const Color darkTextTertiary = Color(0xFF71717A);

  // ─── Light Theme ───
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF5F5F5);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightTextPrimary = Color(0xFF09090B);
  static const Color lightTextSecondary = Color(0xFF52525B);
  static const Color lightTextTertiary = Color(0xFF71717A);

  // ─── Muscle Group Colors ───
  static const Map<String, Color> muscleColors = {
    'chest': Color(0xFFEF4444),
    'back': Color(0xFF10B981),
    'legs': Color(0xFF3B82F6),
    'hamstrings': Color(0xFF06B6D4),
    'shoulders': Color(0xFFF59E0B),
    'biceps': Color(0xFF8B5CF6),
    'triceps': Color(0xFFEC4899),
    'core': Color(0xFFFBBF24),
    'cardio': Color(0xFF14B8A6),
  };
}
