/// Estados possíveis de uma sessão de trabalho (o período entre "Ficar
/// online" e "Ficar offline"):
///
/// offline → online → corridaIniciada → comPassageiro → online → ...
///
/// De `online`, o motociclista pode iniciar uma corrida ou ficar offline.
/// De `corridaIniciada`, pode cancelar (volta pra online) ou pegar o
/// passageiro (vai pra comPassageiro). De `comPassageiro`, só pode
/// finalizar a corrida (volta pra online).
enum StatusSessao { offline, online, corridaIniciada, comPassageiro }

enum TipoEvento {
  ficouOnline,
  iniciouCorrida,
  cancelouCorrida,
  pegouPassageiro,
  finalizouCorrida,
  ficouOffline,
}
