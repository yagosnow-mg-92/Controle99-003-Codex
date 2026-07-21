import 'status_sessao.dart';

/// Um clique importante durante a sessão (ficou online, iniciou corrida,
/// cancelou, pegou passageiro, finalizou, ficou offline), com a
/// localização e o endereço (rua/bairro) no momento exato do clique.
class EventoSessao {
  final String id;
  final String sessaoId;
  final TipoEvento tipo;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? rua;
  final String? bairro;

  const EventoSessao({
    required this.id,
    required this.sessaoId,
    required this.tipo,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.rua,
    this.bairro,
  });
}
