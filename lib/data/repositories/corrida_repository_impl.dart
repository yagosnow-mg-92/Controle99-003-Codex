import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../domain/entities/corrida.dart';
import '../../domain/entities/evento_sessao.dart';
import '../../domain/entities/ponto_rota.dart';
import '../../domain/entities/sessao_trabalho.dart';
import '../../domain/entities/status_sessao.dart';
import '../../domain/repositories/corrida_repository.dart';

class CorridaRepositoryImpl implements CorridaRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  CorridaRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<SessaoTrabalho?> sessaoAberta() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sessoes_trabalho',
      where: 'fim IS NULL',
      orderBy: 'inicio DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _sessaoFromMap(rows.first);
  }

  @override
  Future<SessaoTrabalho> criarSessao(DateTime inicio) async {
    final db = await _dbHelper.database;
    final sessao = SessaoTrabalho(
      id: _uuid.v4(),
      inicio: inicio,
      status: StatusSessao.online,
    );
    await db.insert('sessoes_trabalho', {
      'id': sessao.id,
      'inicio': sessao.inicio.toIso8601String(),
      'fim': null,
      'status': sessao.status.name,
    });
    return sessao;
  }

  @override
  Future<void> atualizarStatusSessao(String sessaoId, StatusSessao status) async {
    final db = await _dbHelper.database;
    await db.update(
      'sessoes_trabalho',
      {'status': status.name},
      where: 'id = ?',
      whereArgs: [sessaoId],
    );
  }

  @override
  Future<void> encerrarSessao(String sessaoId, DateTime fim) async {
    final db = await _dbHelper.database;
    await db.update(
      'sessoes_trabalho',
      {'fim': fim.toIso8601String(), 'status': StatusSessao.offline.name},
      where: 'id = ?',
      whereArgs: [sessaoId],
    );
  }

  @override
  Future<void> registrarEvento(EventoSessao evento) async {
    final db = await _dbHelper.database;
    await db.insert('eventos_sessao', {
      'id': evento.id,
      'sessao_id': evento.sessaoId,
      'tipo': evento.tipo.name,
      'timestamp': evento.timestamp.toIso8601String(),
      'latitude': evento.latitude,
      'longitude': evento.longitude,
      'rua': evento.rua,
      'bairro': evento.bairro,
    });
  }

  @override
  Future<Corrida> criarCorrida({
    required String sessaoId,
    required DateTime horaInicio,
    required double valor,
  }) async {
    final db = await _dbHelper.database;
    final corrida = Corrida(
      id: _uuid.v4(),
      sessaoId: sessaoId,
      horaInicio: horaInicio,
      valor: valor,
    );
    await db.insert('corridas', {
      'id': corrida.id,
      'sessao_id': corrida.sessaoId,
      'hora_inicio': corrida.horaInicio.toIso8601String(),
      'hora_fim': null,
      'valor': corrida.valor,
      'cancelada': 0,
      'km_percorrido': 0,
      'receita_id': null,
      'local_embarque': null,
      'local_destino': null,
    });
    return corrida;
  }

  @override
  Future<Corrida?> corridaAberta(String sessaoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'corridas',
      where: 'sessao_id = ? AND hora_fim IS NULL',
      whereArgs: [sessaoId],
      orderBy: 'hora_inicio DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _corridaFromMap(rows.first);
  }

  @override
  Future<void> atualizarValorCorrida(
    String corridaId,
    double novoValor, {
    bool? cancelada,
  }) async {
    final db = await _dbHelper.database;
    final valores = <String, Object?>{'valor': novoValor};
    if (cancelada != null) valores['cancelada'] = cancelada ? 1 : 0;
    await db.update('corridas', valores, where: 'id = ?', whereArgs: [corridaId]);
  }

  @override
  Future<void> atualizarLocalEmbarque(String corridaId, String? local) async {
    final db = await _dbHelper.database;
    await db.update(
      'corridas',
      {'local_embarque': local},
      where: 'id = ?',
      whereArgs: [corridaId],
    );
  }

  @override
  Future<void> finalizarCorrida(
    String corridaId,
    DateTime horaFim,
    double kmPercorrido, {
    String? localDestino,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'corridas',
      {
        'hora_fim': horaFim.toIso8601String(),
        'km_percorrido': kmPercorrido,
        if (localDestino != null) 'local_destino': localDestino,
      },
      where: 'id = ?',
      whereArgs: [corridaId],
    );
  }

  @override
  Future<void> vincularReceita(String corridaId, String receitaId) async {
    final db = await _dbHelper.database;
    await db.update(
      'corridas',
      {'receita_id': receitaId},
      where: 'id = ?',
      whereArgs: [corridaId],
    );
  }

  @override
  Future<void> registrarPontoRota(PontoRota ponto) async {
    final db = await _dbHelper.database;
    await db.insert('pontos_rota', {
      'id': ponto.id,
      'sessao_id': ponto.sessaoId,
      'corrida_id': ponto.corridaId,
      'timestamp': ponto.timestamp.toIso8601String(),
      'latitude': ponto.latitude,
      'longitude': ponto.longitude,
      'precisao_metros': ponto.precisaoMetros,
      'velocidade_mps': ponto.velocidadeMetrosPorSegundo,
      'direcao_graus': ponto.direcaoGraus,
      'altitude_metros': ponto.altitudeMetros,
      'precisao_velocidade_mps': ponto.precisaoVelocidadeMetrosPorSegundo,
      'localizacao_simulada': ponto.localizacaoSimulada ? 1 : 0,
      'aceito_calculo': ponto.aceitoNoCalculo ? 1 : 0,
    });
  }

  @override
  Future<List<PontoRota>> pontosDaCorrida(String corridaId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pontos_rota',
      where: 'corrida_id = ? AND aceito_calculo = 1',
      whereArgs: [corridaId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pontoFromMap).toList();
  }

  @override
  Future<List<PontoRota>> todosPontosDaCorrida(String corridaId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pontos_rota',
      where: 'corrida_id = ?',
      whereArgs: [corridaId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pontoFromMap).toList();
  }

  @override
  Future<List<PontoRota>> todosPontosDaSessao(String sessaoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pontos_rota',
      where: 'sessao_id = ?',
      whereArgs: [sessaoId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pontoFromMap).toList();
  }

  @override
  Future<List<PontoRota>> pontosDeDeslocamentoNaoLancados(String sessaoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pontos_rota',
      where: 'sessao_id = ? AND corrida_id IS NULL AND lancado_como_deslocamento = 0',
      whereArgs: [sessaoId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pontoFromMap).toList();
  }

  @override
  Future<void> salvarDeslocamentoLivre({
    required String id,
    required String sessaoId,
    required DateTime inicio,
    required DateTime fim,
    required double kmPercorrido,
    required String receitaId,
  }) async {
    final db = await _dbHelper.database;
    await db.insert('deslocamentos_livres', {
      'id': id,
      'sessao_id': sessaoId,
      'inicio': inicio.toIso8601String(),
      'fim': fim.toIso8601String(),
      'km_percorrido': kmPercorrido,
      'receita_id': receitaId,
    });
  }

  @override
  Future<void> marcarPontosComoDeslocamentoLancado(List<String> pontoIds) async {
    if (pontoIds.isEmpty) return;
    final db = await _dbHelper.database;
    final marcadores = List.filled(pontoIds.length, '?').join(', ');
    await db.update(
      'pontos_rota',
      {'lancado_como_deslocamento': 1},
      where: 'id IN ($marcadores)',
      whereArgs: pontoIds,
    );
  }

  @override
  Future<void> vincularPontosAoDeslocamento(List<String> pontoIds, String deslocamentoId) async {
    if (pontoIds.isEmpty) return;
    final db = await _dbHelper.database;
    final marcadores = List.filled(pontoIds.length, '?').join(', ');
    await db.update(
      'pontos_rota',
      {'lancado_como_deslocamento': 1, 'deslocamento_id': deslocamentoId},
      where: 'id IN ($marcadores)',
      whereArgs: pontoIds,
    );
  }

  @override
  Future<List<PontoRota>> pontosDoDeslocamentoPorReceita(String receitaId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pontos_rota',
      where: 'deslocamento_id = (SELECT id FROM deslocamentos_livres WHERE receita_id = ?)',
      whereArgs: [receitaId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pontoFromMap).toList();
  }

  @override
  Future<List<PontoRota>> pontosDaCorridaPorReceita(String receitaId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'pontos_rota',
      where: 'corrida_id = (SELECT id FROM corridas WHERE receita_id = ?)',
      whereArgs: [receitaId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(_pontoFromMap).toList();
  }

  @override
  Future<List<SessaoTrabalho>> listarSessoes() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sessoes_trabalho',
      where: 'fim IS NOT NULL',
      orderBy: 'inicio DESC',
    );
    return rows.map(_sessaoFromMap).toList();
  }

  @override
  Future<List<Corrida>> listarCorridasDaSessao(String sessaoId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'corridas',
      where: 'sessao_id = ?',
      whereArgs: [sessaoId],
      orderBy: 'hora_inicio ASC',
    );
    return rows.map(_corridaFromMap).toList();
  }

  SessaoTrabalho _sessaoFromMap(Map<String, Object?> map) {
    return SessaoTrabalho(
      id: map['id'] as String,
      inicio: DateTime.parse(map['inicio'] as String),
      fim: map['fim'] != null ? DateTime.parse(map['fim'] as String) : null,
      status: StatusSessao.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => StatusSessao.offline,
      ),
    );
  }

  Corrida _corridaFromMap(Map<String, Object?> map) {
    return Corrida(
      id: map['id'] as String,
      sessaoId: map['sessao_id'] as String,
      horaInicio: DateTime.parse(map['hora_inicio'] as String),
      horaFim: map['hora_fim'] != null ? DateTime.parse(map['hora_fim'] as String) : null,
      valor: (map['valor'] as num).toDouble(),
      cancelada: (map['cancelada'] as int) == 1,
      kmPercorrido: (map['km_percorrido'] as num).toDouble(),
      receitaId: map['receita_id'] as String?,
      localEmbarque: map['local_embarque'] as String?,
      localDestino: map['local_destino'] as String?,
    );
  }

  PontoRota _pontoFromMap(Map<String, Object?> map) {
    return PontoRota(
      id: map['id'] as String,
      sessaoId: map['sessao_id'] as String,
      corridaId: map['corrida_id'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      precisaoMetros: (map['precisao_metros'] as num?)?.toDouble(),
      velocidadeMetrosPorSegundo: (map['velocidade_mps'] as num?)?.toDouble(),
      direcaoGraus: (map['direcao_graus'] as num?)?.toDouble(),
      altitudeMetros: (map['altitude_metros'] as num?)?.toDouble(),
      precisaoVelocidadeMetrosPorSegundo:
          (map['precisao_velocidade_mps'] as num?)?.toDouble(),
      localizacaoSimulada: (map['localizacao_simulada'] as int? ?? 0) == 1,
      aceitoNoCalculo: (map['aceito_calculo'] as int? ?? 1) == 1,
    );
  }
}
