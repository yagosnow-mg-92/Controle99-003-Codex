import 'package:collection/collection.dart';

import '../../domain/entities/despesa.dart';
import '../../domain/entities/receita.dart';
import '../../domain/entities/resumo_periodo.dart';

/// Camada de "inteligência" do app: recebe listas cruas de receitas e
/// despesas e calcula todos os indicadores derivados. Fica isolada para
/// que Dashboard e tela de Indicadores reutilizem exatamente a mesma lógica.
class IndicadoresService {
  ResumoPeriodo calcular({
    required List<Receita> receitas,
    required List<Despesa> despesas,
    DateTime? inicio,
    DateTime? fim,
  }) {
    final receitaTotal = receitas.fold<double>(0, (s, r) => s + r.valorRecebido);
    final despesaTotal = despesas.fold<double>(0, (s, d) => s + d.valor);
    final kmRodados = receitas.fold<double>(0, (s, r) => s + r.kmRodados);

    final receitasPorDia = groupBy(receitas, (Receita r) => _apenasData(r.data));
    final totalPorDia = receitasPorDia.map(
      (dia, lista) => MapEntry(dia, lista.fold<double>(0, (s, r) => s + r.valorRecebido)),
    );

    MapEntry<DateTime, double>? melhor;
    MapEntry<DateTime, double>? pior;
    for (final entry in totalPorDia.entries) {
      if (melhor == null || entry.value > melhor.value) melhor = entry;
      if (pior == null || entry.value < pior.value) pior = entry;
    }

    final despesasPorCategoria = <String, double>{};
    for (final d in despesas) {
      despesasPorCategoria[d.categoria] =
          (despesasPorCategoria[d.categoria] ?? 0) + d.valor;
    }

    final maiorDespesa = despesas.isEmpty
        ? 0.0
        : despesas.map((d) => d.valor).reduce((a, b) => a > b ? a : b);

    final numeroDias = (inicio != null && fim != null)
        ? fim.difference(inicio).inDays.clamp(1, 100000)
        : 1;

    final maiorSequencia = _calcularMaiorSequenciaLucrativa(receitas, despesas);

    return ResumoPeriodo(
      receitaTotal: receitaTotal,
      despesaTotal: despesaTotal,
      lucroLiquido: receitaTotal - despesaTotal,
      kmRodados: kmRodados,
      quantidadeReceitas: receitas.length,
      quantidadeDespesas: despesas.length,
      maiorReceitaDiaria: melhor?.value ?? 0,
      maiorDespesa: maiorDespesa,
      melhorDia: melhor?.key,
      piorDia: pior?.key,
      despesasPorCategoria: despesasPorCategoria,
      numeroDias: numeroDias,
      maiorSequenciaLucrativa: maiorSequencia,
    );
  }

  /// Percorre os dias com algum lançamento (receita ou despesa), em ordem
  /// cronológica, e encontra a maior sequência de dias consecutivos no
  /// calendário (sem pular nenhum) em que o lucro do dia foi positivo.
  int _calcularMaiorSequenciaLucrativa(List<Receita> receitas, List<Despesa> despesas) {
    final lucroPorDia = <DateTime, double>{};
    for (final r in receitas) {
      final dia = _apenasData(r.data);
      lucroPorDia[dia] = (lucroPorDia[dia] ?? 0) + r.valorRecebido;
    }
    for (final d in despesas) {
      final dia = _apenasData(d.data);
      lucroPorDia[dia] = (lucroPorDia[dia] ?? 0) - d.valor;
    }

    final diasOrdenados = lucroPorDia.keys.toList()..sort();

    int maiorSequencia = 0;
    int sequenciaAtual = 0;
    DateTime? diaAnterior;

    for (final dia in diasOrdenados) {
      final lucrativo = lucroPorDia[dia]! > 0;
      final consecutivoAoAnterior =
          diaAnterior != null && dia.difference(diaAnterior).inDays == 1;

      if (lucrativo) {
        sequenciaAtual = consecutivoAoAnterior ? sequenciaAtual + 1 : 1;
        if (sequenciaAtual > maiorSequencia) maiorSequencia = sequenciaAtual;
      } else {
        sequenciaAtual = 0;
      }
      diaAnterior = dia;
    }

    return maiorSequencia;
  }

  DateTime _apenasData(DateTime d) => DateTime(d.year, d.month, d.day);
}
