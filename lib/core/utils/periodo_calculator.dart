import '../../domain/entities/periodo_filtro.dart';

/// Calcula o intervalo [inicio, fim) correspondente a um [PeriodoFiltro].
/// `fim` é sempre exclusivo (meia-noite do dia seguinte ao último dia do
/// período), compatível com as consultas `>= inicio AND < fim` usadas nos
/// repositórios.
///
/// Compartilhado entre Dashboard e Indicadores para garantir que "Semana
/// atual", "Mês atual" etc. signifiquem exatamente a mesma coisa em
/// qualquer tela do app.
({DateTime inicio, DateTime fim}) calcularIntervaloPeriodo(
  PeriodoFiltro filtro, {
  DateTime? personalizadoInicio,
  DateTime? personalizadoFim,
}) {
  final agora = DateTime.now();
  final hoje = DateTime(agora.year, agora.month, agora.day);

  switch (filtro) {
    case PeriodoFiltro.dia:
      return (inicio: hoje, fim: hoje.add(const Duration(days: 1)));

    case PeriodoFiltro.semana:
      // Semana começando na segunda-feira.
      final inicioSemana = hoje.subtract(Duration(days: hoje.weekday - 1));
      return (inicio: inicioSemana, fim: inicioSemana.add(const Duration(days: 7)));

    case PeriodoFiltro.mes:
      final inicioMes = DateTime(hoje.year, hoje.month, 1);
      final inicioProximoMes = DateTime(hoje.year, hoje.month + 1, 1);
      return (inicio: inicioMes, fim: inicioProximoMes);

    case PeriodoFiltro.trimestre:
      final trimestreAtual = ((hoje.month - 1) ~/ 3);
      final mesInicioTrimestre = trimestreAtual * 3 + 1;
      final inicioTrimestre = DateTime(hoje.year, mesInicioTrimestre, 1);
      final inicioProximoTrimestre = DateTime(hoje.year, mesInicioTrimestre + 3, 1);
      return (inicio: inicioTrimestre, fim: inicioProximoTrimestre);

    case PeriodoFiltro.ano:
      return (inicio: DateTime(hoje.year, 1, 1), fim: DateTime(hoje.year + 1, 1, 1));

    case PeriodoFiltro.personalizado:
      final inicio = personalizadoInicio ?? hoje.subtract(const Duration(days: 7));
      final fim = personalizadoFim ?? hoje;
      final fimExclusivo = DateTime(fim.year, fim.month, fim.day).add(const Duration(days: 1));
      return (inicio: DateTime(inicio.year, inicio.month, inicio.day), fim: fimExclusivo);
  }
}
