import 'package:flutter/material.dart';

/// Paleta de cores do Moto Gestor.
/// Conceito: fundo escuro premium, verde para ganhos, vermelho/laranja para
/// despesas, azul para indicadores neutros (km, médias).
class AppColors {
  AppColors._();

  // Base
  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF161B22);
  static const Color surfaceElevated = Color(0xFF1E242D);
  static const Color border = Color(0xFF2A3140);

  // Texto
  static const Color textPrimary = Color(0xFFF2F4F7);
  static const Color textSecondary = Color(0xFF9AA4B2);
  static const Color textDisabled = Color(0xFF5A6472);

  // Semânticas financeiras
  static const Color receita = Color(0xFF22C55E);
  static const Color receitaSoft = Color(0xFF16341F);
  static const Color despesa = Color(0xFFEF4444);
  static const Color despesaSoft = Color(0xFF3A1A1A);
  static const Color lucro = Color(0xFF3B82F6);
  static const Color lucroSoft = Color(0xFF16233A);
  static const Color alerta = Color(0xFFF59E0B);

  // Marca
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryVariant = Color(0xFF4F46E5);

  static const List<Color> chartGradientReceita = [
    Color(0xFF22C55E),
    Color(0xFF16A34A),
  ];
  static const List<Color> chartGradientDespesa = [
    Color(0xFFEF4444),
    Color(0xFFB91C1C),
  ];

  static const List<Color> pieCategoryColors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
  ];
}
