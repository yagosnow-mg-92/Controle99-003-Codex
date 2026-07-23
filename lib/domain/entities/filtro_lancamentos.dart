/// Controla somente a exibição das listas de lançamentos. Nunca deve ser
/// usado para excluir receitas dos indicadores, gráficos ou cálculos de km.
enum FiltroLancamentos {
  todos('Todos'),
  somenteCorridas('Somente corridas');

  final String descricao;
  const FiltroLancamentos(this.descricao);
}
