import 'package:flutter/material.dart';

class AppColors {
  // Primary & Accents
  static const Color primaryNeon = Color(0xFF38DEBB);
  static const Color onPrimary = Color(0xFF00382D);
  static const Color onPrimaryContainer = Color(0xFF009379);

  // Backgrounds & Surfaces
  static const Color baseSurface = Color(0xFF041329);
  static const Color surfaceDim = Color(0xFF041329);
  static const Color surfaceBright = Color(0xFF2C3951);

  // Surface Containers (Organic Layering)
  static const Color surfaceContainerLowest = Color(0xFF010E24);
  static const Color surfaceContainerLow = Color(0xFF0D1C32);
  static const Color surfaceContainer = Color(0xFF112036);
  static const Color surfaceContainerHigh = Color(0xFF1C2A41);
  static const Color surfaceContainerHighest = Color(0xFF27354C);

  // Text & Metadata
  static const Color onSurface = Color(0xFFD6E3FF);
  static const Color onSurfaceVariant = Color(0xFFC5C6CD);
  static const Color subText = Color(0x99D6E3FF);

  // Outlines & Borders
  static const Color outline = Color(0xFF8F9097);
  static const Color outlineVariant = Color(0xFF44474D);
  static const Color ghostBorder = Color(0x2644474D); // 15% Opacity Outline Variant

  // Backward Compatibility Mappings
  static const Color containerLow = surfaceContainerLow;
  static const Color containerHighest = surfaceContainerHighest;
}