import 'package:flutter/material.dart';

/// Paleta de cores do Moto Gestor.
///
/// Os campos são expostos como getters estáticos (`AppColors.background`,
/// `AppColors.textPrimary` etc.) que sempre apontam para o tema ativo
/// no momento — [dark] ou [light] — trocado via [definirTema]. Isso
/// preserva todo o código existente das telas (que já usa `AppColors.algo`
/// diretamente) sem precisar reescrever centenas de referências espalhadas
/// pelo app: só o "de onde vem a cor" mudou, não o "como a tela pede a cor".
class _PaletaCores {
  const _PaletaCores({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.receita,
    required this.receitaSoft,
    required this.despesa,
    required this.despesaSoft,
    required this.lucro,
    required this.lucroSoft,
    required this.alerta,
    required this.primary,
    required this.primaryVariant,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;

  final Color receita;
  final Color receitaSoft;
  final Color despesa;
  final Color despesaSoft;
  final Color lucro;
  final Color lucroSoft;
  final Color alerta;

  final Color primary;
  final Color primaryVariant;
}

class AppColors {
  AppColors._();

  /// Tema escuro — visual original do app, bom para uso à noite.
  static const _PaletaCores _dark = _PaletaCores(
    background: Color(0xFF0E1116),
    surface: Color(0xFF161B22),
    surfaceElevated: Color(0xFF1E242D),
    border: Color(0xFF2A3140),
    textPrimary: Color(0xFFF2F4F7),
    textSecondary: Color(0xFF9AA4B2),
    textDisabled: Color(0xFF5A6472),
    receita: Color(0xFF22C55E),
    receitaSoft: Color(0xFF16341F),
    despesa: Color(0xFFEF4444),
    despesaSoft: Color(0xFF3A1A1A),
    lucro: Color(0xFF3B82F6),
    lucroSoft: Color(0xFF16233A),
    alerta: Color(0xFFF59E0B),
    primary: Color(0xFF6366F1),
    primaryVariant: Color(0xFF4F46E5),
  );

  /// Tema claro — pensado para leitura sob luz do sol: fundo levemente
  /// acinzentado (evita o brilho estourado de um branco puro), texto quase
  /// preto para contraste máximo, e as cores semânticas (receita/despesa/
  /// lucro/alerta) escurecidas em relação ao tema escuro, porque um tom
  /// vibrante e claro que funciona sobre fundo escuro fica com contraste
  /// ruim sobre fundo branco.
  static const _PaletaCores _light = _PaletaCores(
    background: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F2F5),
    border: Color(0xFFDCE0E6),
    textPrimary: Color(0xFF14181F),
    textSecondary: Color(0xFF4B5563),
    textDisabled: Color(0xFF9AA4B2),
    receita: Color(0xFF15803D),
    receitaSoft: Color(0xFFE3F6E9),
    despesa: Color(0xFFC1121F),
    despesaSoft: Color(0xFFFBE7E8),
    lucro: Color(0xFF1D4ED8),
    lucroSoft: Color(0xFFE3EBFC),
    alerta: Color(0xFF9A5B00),
    primary: Color(0xFF4F46E5),
    primaryVariant: Color(0xFF4338CA),
  );

  static _PaletaCores _ativa = _dark;

  /// Troca a paleta ativa. Quem chama isso é o `TemaProvider`; depois de
  /// chamar, é preciso forçar um rebuild de toda a árvore de widgets (o
  /// `TemaProvider` faz isso trocando a `Key` da tela raiz em `main.dart`),
  /// porque estes são getters estáticos lidos no momento do `build()`, não
  /// algo que o Flutter observa automaticamente widget a widget.
  static void definirTema({required bool escuro}) {
    _ativa = escuro ? _dark : _light;
  }

  static bool get temaEscuroAtivo => identical(_ativa, _dark);

  static Color get background => _ativa.background;
  static Color get surface => _ativa.surface;
  static Color get surfaceElevated => _ativa.surfaceElevated;
  static Color get border => _ativa.border;

  static Color get textPrimary => _ativa.textPrimary;
  static Color get textSecondary => _ativa.textSecondary;
  static Color get textDisabled => _ativa.textDisabled;

  static Color get receita => _ativa.receita;
  static Color get receitaSoft => _ativa.receitaSoft;
  static Color get despesa => _ativa.despesa;
  static Color get despesaSoft => _ativa.despesaSoft;
  static Color get lucro => _ativa.lucro;
  static Color get lucroSoft => _ativa.lucroSoft;
  static Color get alerta => _ativa.alerta;

  static Color get primary => _ativa.primary;
  static Color get primaryVariant => _ativa.primaryVariant;

  // Cores de gráfico não dependem do tema — servem só para diferenciar
  // categorias visualmente, então ficam fixas nas duas versões do app.
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
