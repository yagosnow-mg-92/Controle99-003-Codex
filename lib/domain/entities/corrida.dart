/// Uma corrida individual dentro de uma sessão de trabalho.
class Corrida {
  final String id;
  final String sessaoId;
  final DateTime horaInicio;
  final DateTime? horaFim;
  final double valor;
  final bool cancelada;
  final double kmPercorrido;
  final String? receitaId;
  final String? localEmbarque;
  final String? localDestino;

  const Corrida({
    required this.id,
    required this.sessaoId,
    required this.horaInicio,
    this.horaFim,
    required this.valor,
    this.cancelada = false,
    this.kmPercorrido = 0,
    this.receitaId,
    this.localEmbarque,
    this.localDestino,
  });

  Duration get duracao => (horaFim ?? DateTime.now()).difference(horaInicio);

  Corrida copyWith({
    DateTime? horaFim,
    double? valor,
    bool? cancelada,
    double? kmPercorrido,
    String? receitaId,
    String? localEmbarque,
    String? localDestino,
  }) {
    return Corrida(
      id: id,
      sessaoId: sessaoId,
      horaInicio: horaInicio,
      horaFim: horaFim ?? this.horaFim,
      valor: valor ?? this.valor,
      cancelada: cancelada ?? this.cancelada,
      kmPercorrido: kmPercorrido ?? this.kmPercorrido,
      receitaId: receitaId ?? this.receitaId,
      localEmbarque: localEmbarque ?? this.localEmbarque,
      localDestino: localDestino ?? this.localDestino,
    );
  }
}
