import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/indicadores_service.dart';
import '../../core/utils/periodo_calculator.dart';
import '../../domain/entities/despesa.dart';
import '../../domain/entities/periodo_filtro.dart';
import '../../domain/entities/receita.dart';
import '../../domain/entities/resumo_periodo.dart';
import '../../domain/repositories/despesa_repository.dart';
import '../../domain/repositories/receita_repository.dart';

/// Estado da tela Dashboard. Sempre que um lançamento é salvo em qualquer
/// parte do app, `carregar()` deve ser chamado para que os indicadores
/// sejam recalculados automaticamente — cumprindo o requisito de
/// "inteligência" do aplicativo.
class DashboardProvider extends ChangeNotifier {
  final ReceitaRepository _receitaRepository;
  final DespesaRepository _despesaRepository;
  final IndicadoresService _indicadoresService;
  final DatabaseHelper _dbHelper;

  DashboardProvider({
    required ReceitaRepository receitaRepository,
    required DespesaRepository despesaRepository,
    IndicadoresService? indicadoresService,
    DatabaseHelper? dbHelper,
  })  : _receitaRepository = receitaRepository,
        _despesaRepository = despesaRepository,
        _indicadoresService = indicadoresService ?? IndicadoresService(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  static const _chavePeriodo = 'dashboard_periodo';
  static const _chavePeriodoInicio = 'dashboard_periodo_inicio';
  static const _chavePeriodoFim = 'dashboard_periodo_fim';

  bool carregando = true;
  PeriodoFiltro periodo = PeriodoFiltro.dia;
  DateTime periodoPersonalizadoInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime periodoPersonalizadoFim = DateTime.now();

  ResumoPeriodo resumoPeriodo = const ResumoPeriodo();
  List<Receita> ultimasReceitas = [];
  List<Despesa> ultimasDespesas = [];

  /// Lucro/receita dia a dia dos últimos 7 dias, com a data de cada ponto
  /// (necessária para rotular o gráfico corretamente).
  List<({DateTime dia, double receita, double lucro})> ultimos7Dias = [];

  Future<void> carregar() async {
    carregando = true;
    notifyListeners();

    await _carregarPreferenciaPeriodo();

    final intervalo = calcularIntervaloPeriodo(
      periodo,
      personalizadoInicio: periodoPersonalizadoInicio,
      personalizadoFim: periodoPersonalizadoFim,
    );

    final receitasPeriodo = await _receitaRepository.listar(
      inicio: intervalo.inicio,
      fim: intervalo.fim,
    );
    final despesasPeriodo = await _despesaRepository.listar(
      inicio: intervalo.inicio,
      fim: intervalo.fim,
    );

    resumoPeriodo = _indicadoresService.calcular(
      receitas: receitasPeriodo,
      despesas: despesasPeriodo,
      inicio: intervalo.inicio,
      fim: intervalo.fim,
    );

    final todasReceitas = await _receitaRepository.listar();
    final todasDespesas = await _despesaRepository.listar();

    ultimasReceitas = todasReceitas.take(5).toList();
    ultimasDespesas = todasDespesas.take(5).toList();

    ultimos7Dias = await _calcularUltimosDias(7);

    carregando = false;
    notifyListeners();
  }

  Future<void> mudarPeriodo(PeriodoFiltro novoPeriodo) async {
    periodo = novoPeriodo;
    await _salvarPreferenciaPeriodo();
    await carregar();
  }

  Future<void> definirPeriodoPersonalizado(DateTime inicio, DateTime fim) async {
    periodoPersonalizadoInicio = inicio;
    periodoPersonalizadoFim = fim;
    periodo = PeriodoFiltro.personalizado;
    await _salvarPreferenciaPeriodo();
    await carregar();
  }

  Future<void> _carregarPreferenciaPeriodo() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'configuracoes',
      where: 'chave IN (?, ?, ?)',
      whereArgs: [_chavePeriodo, _chavePeriodoInicio, _chavePeriodoFim],
    );
    final mapa = {for (final row in rows) row['chave'] as String: row['valor'] as String};

    final nomePeriodo = mapa[_chavePeriodo];
    if (nomePeriodo != null) {
      periodo = PeriodoFiltro.values.firstWhere(
        (p) => p.name == nomePeriodo,
        orElse: () => PeriodoFiltro.dia,
      );
    }

    final inicioSalvo = mapa[_chavePeriodoInicio];
    final fimSalvo = mapa[_chavePeriodoFim];
    if (inicioSalvo != null) periodoPersonalizadoInicio = DateTime.parse(inicioSalvo);
    if (fimSalvo != null) periodoPersonalizadoFim = DateTime.parse(fimSalvo);
  }

  Future<void> _salvarPreferenciaPeriodo() async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.insert(
      'configuracoes',
      {'chave': _chavePeriodo, 'valor': periodo.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'configuracoes',
      {'chave': _chavePeriodoInicio, 'valor': periodoPersonalizadoInicio.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'configuracoes',
      {'chave': _chavePeriodoFim, 'valor': periodoPersonalizadoFim.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  Future<List<({DateTime dia, double receita, double lucro})>> _calcularUltimosDias(
    int dias,
  ) async {
    final resultado = <({DateTime dia, double receita, double lucro})>[];
    final hoje = DateTime.now();

    for (int i = dias - 1; i >= 0; i--) {
      final dia = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: i));
      final proximoDia = dia.add(const Duration(days: 1));

      final receitas = await _receitaRepository.listar(inicio: dia, fim: proximoDia);
      final despesas = await _despesaRepository.listar(inicio: dia, fim: proximoDia);

      final receitaTotal = receitas.fold<double>(0, (s, r) => s + r.valorRecebido);
      final despesaTotal = despesas.fold<double>(0, (s, d) => s + d.valor);

      resultado.add((dia: dia, receita: receitaTotal, lucro: receitaTotal - despesaTotal));
    }

    return resultado;
  }
}
