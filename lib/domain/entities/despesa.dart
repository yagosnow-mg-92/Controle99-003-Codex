class Despesa {
  final String id;
  final DateTime data;
  final String categoria;
  final double valor;
  final String? observacao;
  final DateTime criadoEm;

  const Despesa({
    required this.id,
    required this.data,
    required this.categoria,
    required this.valor,
    this.observacao,
    required this.criadoEm,
  });

  Despesa copyWith({
    String? id,
    DateTime? data,
    String? categoria,
    double? valor,
    String? observacao,
    DateTime? criadoEm,
  }) {
    return Despesa(
      id: id ?? this.id,
      data: data ?? this.data,
      categoria: categoria ?? this.categoria,
      valor: valor ?? this.valor,
      observacao: observacao ?? this.observacao,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}
