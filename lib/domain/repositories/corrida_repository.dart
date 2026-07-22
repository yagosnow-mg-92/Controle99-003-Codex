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

  /// Chamado ao "Peguei o passageiro" — grava onde o embarque aconteceu.
  Future<void> atualizarLocalEmbarque(String corridaId, String? local);

  Future<void> finalizarCorrida(
    String corridaId,
    DateTime horaFim,
    double kmPercorrido, {
    String? localDestino,
  });
  Future<void> vincularReceita(String corridaId, String receitaId);

  Future<void> registrarPontoRota(PontoRota ponto);
  /// Pontos aprovados pelo filtro, usados no cálculo financeiro.
  Future<List<PontoRota>> pontosDaCorrida(String corridaId);
  /// Traçado completo, inclusive pontos descartados no cálculo, para mapa e auditoria.
  Future<List<PontoRota>> todosPontosDaCorrida(String corridaId);
  Future<List<PontoRota>> todosPontosDaSessao(String sessaoId);

  Future<List<PontoRota>> pontosDeDeslocamentoNaoLancados(String sessaoId);
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
