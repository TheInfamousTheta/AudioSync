import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  // Laser-etched signature gradient sweeping down at 135 degrees (top-left to bottom-right)
  static const LinearGradient laserEtched = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryNeon, AppColors.onPrimaryContainer],
  );

  static const LinearGradient surfaceSmoky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1B33), AppColors.baseSurface],
  );
}
