import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../domain/entities/despesa.dart';
import '../../domain/repositories/despesa_repository.dart';

class DespesaRepositoryImpl implements DespesaRepository {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  DespesaRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Despesa>> listar({DateTime? inicio, DateTime? fim}) async {
    final db = await _dbHelper.database;
    String? where;
    List<Object?>? args;

    // Fim exclusivo — ver comentário equivalente em ReceitaRepositoryImpl.
    if (inicio != null && fim != null) {
      where = 'data >= ? AND data < ?';
      args = [inicio.toIso8601String(), fim.toIso8601String()];
    }

    final rows = await db.query(
      'despesas',
      where: where,
      whereArgs: args,
      orderBy: 'data DESC',
    );

    return rows.map(_fromMap).toList();
  }

  @override
  Future<Despesa?> buscarPorId(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('despesas', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  @override
  Future<void> salvar(Despesa despesa) async {
    final db = await _dbHelper.database;
    final id = despesa.id.isEmpty ? _uuid.v4() : despesa.id;
    final despesaComId = despesa.copyWith(id: id);

    await db.insert(
      'despesas',
      _toMap(despesaComId),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await adicionarCategoria(despesa.categoria);
  }

  @override
  Future<void> excluir(String id) async {
    final db = await _dbHelper.database;
    await db.delete('despesas', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<String>> listarCategorias() async {
    final db = await _dbHelper.database;
    final rows = await db.query('categorias_despesa', orderBy: 'nome ASC');
    return rows.map((r) => r['nome'] as String).toList();
  }

  @override
  Future<void> adicionarCategoria(String nome) async {
    if (nome.trim().isEmpty) return;
    final db = await _dbHelper.database;
    await db.insert(
      'categorias_despesa',
      {'nome': nome.trim()},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Map<String, Object?> _toMap(Despesa d) {
    return {
      'id': d.id,
      'data': d.data.toIso8601String(),
      'categoria': d.categoria,
      'valor': d.valor,
      'observacao': d.observacao,
      'criado_em': d.criadoEm.toIso8601String(),
    };
  }

  Despesa _fromMap(Map<String, Object?> map) {
    return Despesa(
      id: map['id'] as String,
      data: DateTime.parse(map['data'] as String),
      categoria: map['categoria'] as String,
      valor: (map['valor'] as num).toDouble(),
      observacao: map['observacao'] as String?,
      criadoEm: DateTime.parse(map['criado_em'] as String),
    );
  }
}
