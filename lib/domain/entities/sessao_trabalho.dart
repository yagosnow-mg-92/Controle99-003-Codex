import 'status_sessao.dart';

/// Representa o período entre "Ficar online" e "Ficar offline". Pode
/// conter várias corridas dentro dela.
class SessaoTrabalho {
  final String id;
  final DateTime inicio;
  final DateTime? fim;
  final StatusSessao status;

  const SessaoTrabalho({
    required this.id,
    required this.inicio,
    this.fim,
    required this.status,
  });

  Duration get duracao => (fim ?? DateTime.now()).difference(inicio);

  SessaoTrabalho copyWith({DateTime? fim, StatusSessao? status}) {
    return SessaoTrabalho(
      id: id,
      inicio: inicio,
      fim: fim ?? this.fim,
      status: status ?? this.status,
    );
  }
}
