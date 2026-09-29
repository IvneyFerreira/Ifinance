import 'package:flutter/material.dart';

/// IFinance Design System — Paleta de cores.
///
/// Estética: Premium, minimalista, tecnológica, elegante, financeira.
/// Base: grafite profundo, preto suave, branco, cinzas neutros.
/// Destaque: verde esmeralda.
/// Semânticas: verde = positivo, vermelho = negativo, amarelo = atenção, azul = info.
class AppColors {
  AppColors._();

  // Destaque / marca
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF059669);
  static const Color emeraldSoft = Color(0xFF34D399);

  // Base
  static const Color graphite = Color(0xFF14181F);
  static const Color graphiteSoft = Color(0xFF1B212B);
  static const Color blackSoft = Color(0xFF0B0E13);
  static const Color surfaceDark = Color(0xFF11151C);
  static const Color surfaceDarkElevated = Color(0xFF181E28);

  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF7F8FA);
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);

  // Cinzas neutros
  static const Color gray100 = Color(0xFFF1F3F5);
  static const Color gray200 = Color(0xFFE3E6EA);
  static const Color gray300 = Color(0xFFC7CCD3);
  static const Color gray400 = Color(0xFF9AA2AD);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);
  static const Color gray700 = Color(0xFF374151);

  // Semânticas
  static const Color positive = Color(0xFF10B981);
  static const Color negative = Color(0xFFEF4444);
  static const Color negativeSoft = Color(0xFFF87171);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ---- Tokens de tema (light) ----
  static const Color lightBg = surfaceLight;
  static const Color lightCard = surfaceLightElevated;
  static const Color lightBorder = gray200;
  static const Color lightTextPrimary = Color(0xFF0B0E13);
  static const Color lightTextSecondary = gray500;

  // ---- Tokens de tema (dark) ----
  static const Color darkBg = blackSoft;
  static const Color darkCard = surfaceDarkElevated;
  static const Color darkBorder = Color(0xFF232B37);
  static const Color darkTextPrimary = Color(0xFFF3F5F7);
  static const Color darkTextSecondary = Color(0xFF9AA2AD);
}

/// Shapes / raios usados no Design System.
class AppRadius {
  AppRadius._();
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 40;
}
