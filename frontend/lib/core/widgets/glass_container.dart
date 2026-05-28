import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:audio_sync/core/theme/app_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 40.0,
          sigmaY: 40.0,
        ), // System spec blur
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0D1C32).withValues(alpha: 0.7), // Smoky layer
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: AppColors.ghostBorder, width: 1.0),
          ),
          child: child,
        ),
      ),
    );
  }
}
