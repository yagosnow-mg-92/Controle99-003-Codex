import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../domain/entities/receita.dart';
import '../../domain/repositories/receita_repository.dart';

class ReceitaRepositoryImpl implements ReceitaRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  ReceitaRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Receita>> listar({DateTime? inicio, DateTime? fim}) async {
    final db = await _dbHelper.database;
    String? where;
    List<Object?>? args;

    // Usamos `>= inicio AND < fim` (fim exclusivo) em vez de BETWEEN,
    // que é inclusivo nos dois lados no SQLite. Isso evita que um
    // lançamento salvo à meia-noite do dia seguinte seja contado
    // erroneamente dentro do período anterior.
    if (inicio != null && fim != null) {
      where = 'data >= ? AND data < ?';
      args = [inicio.toIso8601String(), fim.toIso8601String()];
    }

    final rows = await db.query(
      'receitas',
      where: where,
      whereArgs: args,
      orderBy: 'data DESC',
    );

    return rows.map(_fromMap).toList();
  }

  @override
  Future<Receita?> buscarPorId(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('receitas', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  @override
  Future<void> salvar(Receita receita) async {
    final db = await _dbHelper.database;
    final id = receita.id.isEmpty ? _uuid.v4() : receita.id;
    final receitaComId = receita.copyWith(id: id);

    await db.insert(
      'receitas',
      _toMap(receitaComId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> excluir(String id) async {
    final db = await _dbHelper.database;
    await db.delete('receitas', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toMap(Receita r) {
    return {
      'id': r.id,
      'data': r.data.toIso8601String(),
      'km_rodados': r.kmRodados,
      'valor_recebido': r.valorRecebido,
      'valor_por_km': r.valorPorKm,
      'observacao': r.observacao,
      'criado_em': r.criadoEm.toIso8601String(),
      'local_embarque': r.localEmbarque,
      'local_destino': r.localDestino,
      'tipo': r.tipo.name,
      'hora_inicio': r.horaInicio?.toIso8601String(),
      'hora_fim': r.horaFim?.toIso8601String(),
    };
  }

  Receita _fromMap(Map<String, Object?> map) {
    return Receita(
      id: map['id'] as String,
      data: DateTime.parse(map['data'] as String),
      kmRodados: (map['km_rodados'] as num).toDouble(),
      valorRecebido: (map['valor_recebido'] as num).toDouble(),
      observacao: map['observacao'] as String?,
      criadoEm: DateTime.parse(map['criado_em'] as String),
      localEmbarque: map['local_embarque'] as String?,
      localDestino: map['local_destino'] as String?,
      tipo: TipoReceita.values.firstWhere(
        (tipo) => tipo.name == map['tipo'],
        orElse: () => TipoReceita.outro,
      ),
      horaInicio: map['hora_inicio'] != null ? DateTime.parse(map['hora_inicio'] as String) : null,
      horaFim: map['hora_fim'] != null ? DateTime.parse(map['hora_fim'] as String) : null,
    );
  }
}
