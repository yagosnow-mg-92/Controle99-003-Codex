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

  /// Onde o motociclista estava quando tocou em "Iniciar corrida" — ainda
  /// a caminho do passageiro, não é o local de embarque.
  final String? localInicio;
  final double? localInicioLat;
  final double? localInicioLng;

  /// Onde o passageiro foi de fato pego (toque em "Peguei o passageiro").
  /// Fica nulo se a corrida for cancelada antes disso.
  final String? localEmbarque;
  final double? localEmbarqueLat;
  final double? localEmbarqueLng;

  /// Onde a corrida terminou — seja por finalização normal, seja por
  /// cancelamento (nesse caso, é o local do cancelamento).
  final String? localDestino;
  final double? localDestinoLat;
  final double? localDestinoLng;

  const Corrida({
    required this.id,
    required this.sessaoId,
    required this.horaInicio,
    this.horaFim,
    required this.valor,
    this.cancelada = false,
    this.kmPercorrido = 0,
    this.receitaId,
    this.localInicio,
    this.localInicioLat,
    this.localInicioLng,
    this.localEmbarque,
    this.localEmbarqueLat,
    this.localEmbarqueLng,
    this.localDestino,
    this.localDestinoLat,
    this.localDestinoLng,
  });

  Duration get duracao => (horaFim ?? DateTime.now()).difference(horaInicio);

  Corrida copyWith({
    DateTime? horaFim,
    double? valor,
    bool? cancelada,
    double? kmPercorrido,
    String? receitaId,
    String? localInicio,
    double? localInicioLat,
    double? localInicioLng,
    String? localEmbarque,
    double? localEmbarqueLat,
    double? localEmbarqueLng,
    String? localDestino,
    double? localDestinoLat,
    double? localDestinoLng,
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
      localInicio: localInicio ?? this.localInicio,
      localInicioLat: localInicioLat ?? this.localInicioLat,
      localInicioLng: localInicioLng ?? this.localInicioLng,
      localEmbarque: localEmbarque ?? this.localEmbarque,
      localEmbarqueLat: localEmbarqueLat ?? this.localEmbarqueLat,
      localEmbarqueLng: localEmbarqueLng ?? this.localEmbarqueLng,
      localDestino: localDestino ?? this.localDestino,
      localDestinoLat: localDestinoLat ?? this.localDestinoLat,
      localDestinoLng: localDestinoLng ?? this.localDestinoLng,
    );
  }
}
