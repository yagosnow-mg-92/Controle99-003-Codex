/// Agrega todos os indicadores financeiros calculados para um período
/// (dia, semana, mês, etc). É o resultado da "inteligência" do app:
/// sempre recalculado a partir dos lançamentos brutos, nunca persistido.
class ResumoPeriodo {
  final double receitaTotal;
  final double despesaTotal;
  final double lucroLiquido;
  final double kmRodados;
  final int quantidadeReceitas;
  final int quantidadeDespesas;
  final double maiorReceitaDiaria;
  final double maiorDespesa;
  final DateTime? melhorDia;
  final DateTime? piorDia;
  final Map<String, double> despesasPorCategoria;

  /// Quantidade de dias cobertos pelo período filtrado — usada para
  /// calcular as médias diária/semanal/mensal.
  final int numeroDias;

  /// Quantidade de dias consecutivos (calendário) com lucro positivo
  /// dentro do período — "melhor sequência de dias lucrativos".
  final int maiorSequenciaLucrativa;

  const ResumoPeriodo({
    this.receitaTotal = 0,
    this.despesaTotal = 0,
    this.lucroLiquido = 0,
    this.kmRodados = 0,
    this.quantidadeReceitas = 0,
    this.quantidadeDespesas = 0,
    this.maiorReceitaDiaria = 0,
    this.maiorDespesa = 0,
    this.melhorDia,
    this.piorDia,
    this.despesasPorCategoria = const {},
    this.numeroDias = 1,
    this.maiorSequenciaLucrativa = 0,
  });

  double get receitaPorKm => kmRodados > 0 ? receitaTotal / kmRodados : 0;
  double get lucroPorKm => kmRodados > 0 ? lucroLiquido / kmRodados : 0;
  double get despesaPorKm => kmRodados > 0 ? despesaTotal / kmRodados : 0;
  double get percentualLucro =>
      receitaTotal > 0 ? (lucroLiquido / receitaTotal) * 100 : 0;
  double get percentualDespesa =>
      receitaTotal > 0 ? (despesaTotal / receitaTotal) * 100 : 0;

  double get _dias => numeroDias > 0 ? numeroDias.toDouble() : 1;

  double get mediaDiariaReceita => receitaTotal / _dias;
  double get mediaDiariaLucro => lucroLiquido / _dias;
  double get mediaSemanalLucro => mediaDiariaLucro * 7;
  double get mediaMensalLucro => mediaDiariaLucro * 30;
}
