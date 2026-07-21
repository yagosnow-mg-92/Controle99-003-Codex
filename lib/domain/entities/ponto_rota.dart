/// Um ponto de GPS gravado durante a sessão. `corridaId` fica nulo
/// enquanto o motociclista está apenas "online" (procurando corrida) e
/// preenchido quando existe uma corrida em andamento. Todos os pontos brutos
/// são preservados para desenhar o mapa no futuro; `aceitoNoCalculo` indica
/// se o ponto passou pelos filtros usados na quilometragem financeira.
class PontoRota {
  final String id;
  final String sessaoId;
  final String? corridaId;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? precisaoMetros;
  final double? velocidadeMetrosPorSegundo;
  final double? direcaoGraus;
  final double? altitudeMetros;
  final double? precisaoVelocidadeMetrosPorSegundo;
  final bool localizacaoSimulada;
  final bool aceitoNoCalculo;

  const PontoRota({
    required this.id,
    required this.sessaoId,
    this.corridaId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.precisaoMetros,
    this.velocidadeMetrosPorSegundo,
    this.direcaoGraus,
    this.altitudeMetros,
    this.precisaoVelocidadeMetrosPorSegundo,
    this.localizacaoSimulada = false,
    this.aceitoNoCalculo = true,
  });
}
