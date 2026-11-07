import 'package:flutter/material.dart';

/// Couleurs des maquettes Stitch du module Profils (designs/animals/*/code.html).
abstract final class PetColors {
  static const primary = Color(0xFF005C55);
  static const primaryContainer = Color(0xFF0F766E);
  static const primaryFixed = Color(0xFF9CF2E8);
  static const primaryFixedDim = Color(0xFF80D5CB);
  static const onPrimaryFixed = Color(0xFF00201D);
  static const onPrimaryFixedVariant = Color(0xFF00504A);

  static const secondary = Color(0xFF8C4E38);
  static const secondaryContainer = Color(0xFFFEAE92);
  static const secondaryFixed = Color(0xFFFFDBCF);
  static const onSecondaryFixed = Color(0xFF380D01);
  static const onSecondaryContainer = Color(0xFF793F2A);

  static const tertiary = Color(0xFF7F4025);
  static const tertiaryFixed = Color(0xFFFFDBCE);
  static const onTertiaryFixed = Color(0xFF370E00);

  static const surface = Color(0xFFF8F9FF);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFEFF4FF);
  static const surfaceContainer = Color(0xFFE6EEFF);
  static const surfaceHigh = Color(0xFFDEE9FC);
  static const surfaceHighest = Color(0xFFD9E3F6);

  static const onSurface = Color(0xFF121C2A);
  static const onSurfaceVariant = Color(0xFF3E4947);
  static const outline = Color(0xFF6E7977);
  static const inverseSurface = Color(0xFF27313F);
  static const inverseOnSurface = Color(0xFFEAF1FF);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald800 = Color(0xFF065F46);
}

/// Ombre « shadow-sm » des cartes.
const petCardShadow = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];

/// Styles typographiques des maquettes (Inter, hérité du thème).
abstract final class PetText {
  static const headlineLgMobile =
      TextStyle(fontSize: 26, height: 34 / 26, fontWeight: FontWeight.w700, color: PetColors.onSurface);
  static const headlineMd =
      TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: PetColors.onSurface);
  static const headlineSm =
      TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: PetColors.onSurface);
  static const bodyLg = TextStyle(fontSize: 16, height: 24 / 16, color: PetColors.onSurface);
  static const bodyMd = TextStyle(fontSize: 14, height: 20 / 14, color: PetColors.onSurfaceVariant);
  static const bodySm = TextStyle(fontSize: 12, height: 16 / 12, color: PetColors.onSurfaceVariant);
  static const labelLg =
      TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600, color: PetColors.onSurface);
  static const labelMd =
      TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w600, color: PetColors.onSurface);
  static const labelSm =
      TextStyle(fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w500, color: PetColors.onSurfaceVariant);
}
