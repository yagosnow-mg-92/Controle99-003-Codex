import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../domain/entities/configuracoes.dart';
import '../../domain/repositories/configuracoes_repository.dart';

/// Persiste as configurações na tabela `configuracoes` (chave/valor),
/// já criada desde a Etapa 1. Cada campo da entidade vira uma linha,
/// o que facilita adicionar novas configurações no futuro sem migração
/// de schema.
class ConfiguracoesRepositoryImpl implements ConfiguracoesRepository {
  final DatabaseHelper _dbHelper;

  ConfiguracoesRepositoryImpl({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const _chaveMotoModelo = 'moto_modelo';
  static const _chaveMotoAno = 'moto_ano';
  static const _chaveConsumoMedio = 'consumo_medio_km_l';
  static const _chaveValorGasolina = 'valor_gasolina';
  static const _chaveMetaDiaria = 'meta_diaria';
  static const _chaveMetaSemanal = 'meta_semanal';
  static const _chaveMetaMensal = 'meta_mensal';

  @override
  Future<Configuracoes> buscar() async {
    final db = await _dbHelper.database;
    final rows = await db.query('configuracoes');
    final mapa = {for (final row in rows) row['chave'] as String: row['valor'] as String};

    double lerDouble(String chave) => double.tryParse(mapa[chave] ?? '') ?? 0;

    return Configuracoes(
      motoModelo: mapa[_chaveMotoModelo] ?? '',
      motoAno: mapa[_chaveMotoAno] ?? '',
      consumoMedioKmL: lerDouble(_chaveConsumoMedio),
      valorGasolina: lerDouble(_chaveValorGasolina),
      metaDiaria: lerDouble(_chaveMetaDiaria),
      metaSemanal: lerDouble(_chaveMetaSemanal),
      metaMensal: lerDouble(_chaveMetaMensal),
    );
  }

  @override
  Future<void> salvar(Configuracoes configuracoes) async {
    final db = await _dbHelper.database;

    final valores = <String, String>{
      _chaveMotoModelo: configuracoes.motoModelo,
      _chaveMotoAno: configuracoes.motoAno,
      _chaveConsumoMedio: configuracoes.consumoMedioKmL.toString(),
      _chaveValorGasolina: configuracoes.valorGasolina.toString(),
      _chaveMetaDiaria: configuracoes.metaDiaria.toString(),
      _chaveMetaSemanal: configuracoes.metaSemanal.toString(),
      _chaveMetaMensal: configuracoes.metaMensal.toString(),
    };

    final batch = db.batch();
    valores.forEach((chave, valor) {
      batch.insert(
        'configuracoes',
        {'chave': chave, 'valor': valor},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }
}
