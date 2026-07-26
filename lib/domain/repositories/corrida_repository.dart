import '../entities/corrida.dart';
import '../entities/evento_sessao.dart';
import '../entities/ponto_rota.dart';
import '../entities/sessao_trabalho.dart';
import '../entities/status_sessao.dart';

abstract class CorridaRepository {
  /// Retorna a sessão em aberto (fim == null), se houver — usada para
  /// restaurar o estado caso o app seja fechado enquanto online.
  Future<SessaoTrabalho?> sessaoAberta();

  Future<SessaoTrabalho> criarSessao(DateTime inicio);
  Future<void> atualizarStatusSessao(String sessaoId, StatusSessao status);
  Future<void> encerrarSessao(String sessaoId, DateTime fim);

  Future<void> registrarEvento(EventoSessao evento);

  Future<Corrida> criarCorrida({
    required String sessaoId,
    required DateTime horaInicio,
    required double valor,
  });
  Future<Corrida?> corridaAberta(String sessaoId);
  Future<void> atualizarValorCorrida(String corridaId, double novoValor, {bool? cancelada});

  /// Chamado ao "Iniciar corrida" — grava de onde o motociclista partiu
  /// (ainda a caminho do passageiro).
  Future<void> atualizarLocalInicio(String corridaId, {String? local, double? lat, double? lng});

  /// Chamado ao "Peguei o passageiro" — grava onde o embarque aconteceu.
  Future<void> atualizarLocalEmbarque(String corridaId, {String? local, double? lat, double? lng});

  Future<void> finalizarCorrida(
    String corridaId,
    DateTime horaFim,
    double kmPercorrido, {
    String? localDestino,
    double? localDestinoLat,
    double? localDestinoLng,
  });
  Future<void> vincularReceita(String corridaId, String receitaId);

  /// Busca a corrida a partir do id da receita gerada por ela — usado
  /// pelo mapa do trajeto, que precisa das coordenadas de início/embarque/
  /// destino, não só do id da receita.
  Future<Corrida?> corridaPorReceita(String receitaId);

  Future<void> registrarPontoRota(PontoRota ponto);
  /// Pontos aprovados pelo filtro rápido de telemetria.
  Future<List<PontoRota>> pontosDaCorrida(String corridaId);
  /// Traçado completo, inclusive pontos descartados no cálculo, para mapa e auditoria.
  Future<List<PontoRota>> todosPontosDaCorrida(String corridaId);
  Future<List<PontoRota>> todosPontosDaSessao(String sessaoId);

  Future<List<PontoRota>> pontosDeDeslocamentoNaoLancados(String sessaoId);

  /// Reivindica retroativamente, por horário, pontos de GPS gravados dentro
  /// da janela de uma corrida mas que ficaram sem `corrida_id` — acontece
  /// quando um ponto chega bem no instante entre "iniciar corrida" e o
  /// serviço em segundo plano processar o aviso de qual corrida está
  /// ativa. Sem isso, esses pontos "órfãos" vazam pro cálculo de
  /// deslocamento livre e criam um lançamento fantasma.
  Future<void> reivindicarPontosPorHorario({
    required String corridaId,
    required String sessaoId,
    required DateTime inicio,
    required DateTime fim,
  });
  Future<void> marcarPontosComoDeslocamentoLancado(List<String> pontoIds);
  Future<void> salvarDeslocamentoLivre({
    required String id,
    required String sessaoId,
    required DateTime inicio,
    required DateTime fim,
    required double kmPercorrido,
    required String receitaId,
  });
  Future<void> vincularPontosAoDeslocamento(List<String> pontoIds, String deslocamentoId);
  Future<List<PontoRota>> pontosDoDeslocamentoPorReceita(String receitaId);

  /// Pontos de rota de uma CORRIDA a partir do id da receita gerada por
  /// ela — usado pelo botão de mapa na tela de Receita, que só tem o id
  /// da receita em mãos, não o da corrida.
  Future<List<PontoRota>> pontosDaCorridaPorReceita(String receitaId);

  /// Lista as sessões já encerradas, mais recentes primeiro — base para
  /// os relatórios futuros mencionados pelo usuário.
  Future<List<SessaoTrabalho>> listarSessoes();
  Future<List<Corrida>> listarCorridasDaSessao(String sessaoId);
}
