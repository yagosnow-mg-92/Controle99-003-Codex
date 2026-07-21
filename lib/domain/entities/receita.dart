enum TipoReceita {
  corrida('Corrida'),
  deslocamentoLivre('Deslocamento livre'),
  outro('Outro');

  final String descricao;
  const TipoReceita(this.descricao);
}

class Receita {
  final String id;
  final DateTime data;
  final double kmRodados;
  final double valorRecebido;
  final String? observacao;
  final DateTime criadoEm;
  final String? localEmbarque;
  final String? localDestino;
  final TipoReceita tipo;

  const Receita({
    required this.id,
    required this.data,
    required this.kmRodados,
    required this.valorRecebido,
    this.observacao,
    required this.criadoEm,
    this.localEmbarque,
    this.localDestino,
    this.tipo = TipoReceita.outro,
  });

  /// Valor recebido por quilômetro rodado. Regra de negócio central do app.
  double get valorPorKm => kmRodados > 0 ? valorRecebido / kmRodados : 0;

  Receita copyWith({
    String? id,
    DateTime? data,
    double? kmRodados,
    double? valorRecebido,
    String? observacao,
    DateTime? criadoEm,
    String? localEmbarque,
    String? localDestino,
    TipoReceita? tipo,
  }) {
    return Receita(
      id: id ?? this.id,
      data: data ?? this.data,
      kmRodados: kmRodados ?? this.kmRodados,
      valorRecebido: valorRecebido ?? this.valorRecebido,
      observacao: observacao ?? this.observacao,
      criadoEm: criadoEm ?? this.criadoEm,
      localEmbarque: localEmbarque ?? this.localEmbarque,
      localDestino: localDestino ?? this.localDestino,
      tipo: tipo ?? this.tipo,
    );
  }
}
