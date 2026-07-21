/// Um ponto de GPS gravado durante a sessão. `corridaId` fica nulo
/// enquanto o motociclista está apenas "online" (procurando corrida) e
/// preenchido quando existe uma corrida em andamento.
class PontoRota {
  final String id;
  final String sessaoId;
  final String? corridaId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;

  const PontoRota({
    required this.id,
    required this.sessaoId,
    this.corridaId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
  });
}
