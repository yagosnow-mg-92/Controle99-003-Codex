import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/periodo_filtro.dart';
import '../../providers/configuracoes_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/indicador_card.dart';

/// Texto amigável para exibir qual período o Dashboard está mostrando.
String _tituloPeriodo(PeriodoFiltro periodo) {
  switch (periodo) {
    case PeriodoFiltro.dia:
      return 'Hoje';
    case PeriodoFiltro.semana:
      return 'Semana atual';
    case PeriodoFiltro.mes:
      return 'Mês atual';
    case PeriodoFiltro.trimestre:
      return 'Trimestre atual';
    case PeriodoFiltro.ano:
      return 'Ano atual';
    case PeriodoFiltro.personalizado:
      return 'Personalizado';
  }
}

/// Sufixo usado nos títulos dos cards (ex: "Receita do dia", "Receita da semana").
String _sufixoPeriodo(PeriodoFiltro periodo) {
  switch (periodo) {
    case PeriodoFiltro.dia:
      return 'do dia';
    case PeriodoFiltro.semana:
      return 'da semana';
    case PeriodoFiltro.mes:
      return 'do mês';
    case PeriodoFiltro.trimestre:
      return 'do trimestre';
    case PeriodoFiltro.ano:
      return 'do ano';
    case PeriodoFiltro.personalizado:
      return 'do período';
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().carregar();
      context.read<ConfiguracoesProvider>().carregar();
    });
  }

  Future<void> _abrirSeletorPeriodo(DashboardProvider provider) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mostrar painel de:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final opcao in [
                  PeriodoFiltro.dia,
                  PeriodoFiltro.semana,
                  PeriodoFiltro.mes,
                ])
                  ListTile(
                    leading: Icon(
                      provider.periodo == opcao
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: provider.periodo == opcao
                          ? AppColors.primary
                          : AppColors.textDisabled,
                    ),
                    title: Text(
                      _tituloPeriodo(opcao),
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await provider.mudarPeriodo(opcao);
                    },
                  ),
                ListTile(
                  leading: Icon(
                    provider.periodo == PeriodoFiltro.personalizado
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: provider.periodo == PeriodoFiltro.personalizado
                        ? AppColors.primary
                        : AppColors.textDisabled,
                  ),
                  title: const Text(
                    'Personalizado (escolher intervalo)',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final resultado = await showDateRangePicker(
                      context: this.context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: provider.periodoPersonalizadoInicio,
                        end: provider.periodoPersonalizadoFim,
                      ),
                      locale: const Locale('pt', 'BR'),
                    );
                    if (resultado != null) {
                      await provider.definirPeriodoPersonalizado(resultado.start, resultado.end);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<DashboardProvider>(
          builder: (context, provider, _) {
            if (provider.carregando) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: provider.carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _Cabecalho(
                    provider: provider,
                    onTapPeriodo: () => _abrirSeletorPeriodo(provider),
                  ),
                  const SizedBox(height: 20),
                  _CardsPrincipais(provider: provider),
                  if (provider.periodo == PeriodoFiltro.dia) ...[
                    const SizedBox(height: 16),
                    const _MetaDiaria(),
                  ],
                  const SizedBox(height: 24),
                  const _TituloSecao('Últimos 7 dias'),
                  const SizedBox(height: 12),
                  _GraficoDesempenho(provider: provider),
                  const SizedBox(height: 24),
                  const _TituloSecao('Últimos lançamentos'),
                  const SizedBox(height: 12),
                  _ListaUltimosLancamentos(provider: provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final DashboardProvider provider;
  final VoidCallback onTapPeriodo;

  const _Cabecalho({required this.provider, required this.onTapPeriodo});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Formatters.dataExtenso(agora),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text(
                'Painel',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: onTapPeriodo,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _tituloPeriodo(provider.periodo),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TituloSecao extends StatelessWidget {
  final String texto;
  const _TituloSecao(this.texto);

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CardsPrincipais extends StatelessWidget {
  final DashboardProvider provider;
  const _CardsPrincipais({required this.provider});

  @override
  Widget build(BuildContext context) {
    final resumo = provider.resumoPeriodo;
    final sufixo = _sufixoPeriodo(provider.periodo);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        IndicadorCard(
          titulo: 'Receita $sufixo',
          valor: Formatters.moeda(resumo.receitaTotal),
          icone: Icons.trending_up_rounded,
          cor: AppColors.receita,
          corFundo: AppColors.receitaSoft,
        ),
        IndicadorCard(
          titulo: 'Despesa $sufixo',
          valor: Formatters.moeda(resumo.despesaTotal),
          icone: Icons.trending_down_rounded,
          cor: AppColors.despesa,
          corFundo: AppColors.despesaSoft,
        ),
        IndicadorCard(
          titulo: 'Lucro $sufixo',
          valor: Formatters.moeda(resumo.lucroLiquido),
          icone: Icons.savings_rounded,
          cor: AppColors.lucro,
          corFundo: AppColors.lucroSoft,
          subtitulo: Formatters.percentual(resumo.percentualLucro),
        ),
        IndicadorCard(
          titulo: 'Km rodados',
          valor: Formatters.km(resumo.kmRodados),
          icone: Icons.route_rounded,
          cor: AppColors.alerta,
          corFundo: AppColors.surfaceElevated,
        ),
        IndicadorCard(
          titulo: 'Ganho por Km',
          valor: Formatters.moeda(resumo.receitaPorKm),
          icone: Icons.speed_rounded,
          cor: AppColors.receita,
          corFundo: AppColors.receitaSoft,
        ),
        IndicadorCard(
          titulo: 'Lucro por Km',
          valor: Formatters.moeda(resumo.lucroPorKm),
          icone: Icons.bolt_rounded,
          cor: AppColors.lucro,
          corFundo: AppColors.lucroSoft,
        ),
      ],
    );
  }
}

class _GraficoDesempenho extends StatelessWidget {
  final DashboardProvider provider;
  const _GraficoDesempenho({required this.provider});

  @override
  Widget build(BuildContext context) {
    final dias = provider.ultimos7Dias;

    if (dias.isEmpty || dias.every((d) => d.receita == 0 && d.lucro == 0)) {
      return const _EstadoVazioGrafico();
    }

    final maiorValor = dias
        .map((d) => d.receita > d.lucro ? d.receita : d.lucro)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final menorValor = dias
        .map((d) => d.lucro < 0 ? d.lucro : 0.0)
        .fold<double>(0, (a, b) => a < b ? a : b);

    final maxY = maiorValor == 0 ? 10.0 : maiorValor * 1.25;
    final minY = menorValor == 0 ? 0.0 : menorValor * 1.25;
    final intervaloEixoY = ((maxY - minY) / 4).clamp(1, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LegendaGrafico(),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervaloEixoY.toDouble(),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceElevated,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final cor = spot.bar.color ?? AppColors.textPrimary;
                      return LineTooltipItem(
                        Formatters.moeda(spot.y),
                        TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 12),
                      );
                    }).toList(),
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: intervaloEixoY.toDouble(),
                      getTitlesWidget: (value, meta) => Text(
                        _valorCompacto(value),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final indice = value.toInt();
                        if (indice < 0 || indice >= dias.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _diaAbreviado(dias[indice].dia),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _linha(dias.map((d) => d.receita).toList(), AppColors.receita),
                  _linha(dias.map((d) => d.lucro).toList(), AppColors.lucro),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ValoresPorDia(dias: dias),
        ],
      ),
    );
  }

  String _diaAbreviado(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}';
  }

  String _valorCompacto(double valor) {
    if (valor.abs() >= 1000) {
      return '${(valor / 1000).toStringAsFixed(1)}k';
    }
    return valor.toStringAsFixed(0);
  }

  LineChartBarData _linha(List<double> valores, Color cor) {
    return LineChartBarData(
      spots: [
        for (int i = 0; i < valores.length; i++) FlSpot(i.toDouble(), valores[i]),
      ],
      isCurved: false,
      color: cor,
      barWidth: 2.5,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3.5,
          color: cor,
          strokeWidth: 2,
          strokeColor: AppColors.surface,
        ),
      ),
      belowBarData: BarAreaData(show: true, color: cor.withOpacity(0.06)),
    );
  }
}

class _LegendaGrafico extends StatelessWidget {
  const _LegendaGrafico();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _ItemLegenda(cor: AppColors.receita, texto: 'Receita'),
        SizedBox(width: 16),
        _ItemLegenda(cor: AppColors.lucro, texto: 'Lucro'),
      ],
    );
  }
}

class _ItemLegenda extends StatelessWidget {
  final Color cor;
  final String texto;
  const _ItemLegenda({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// Lista os valores de cada um dos 7 dias por extenso, para que o usuário
/// veja os números exatos sem precisar tocar no gráfico.
class _ValoresPorDia extends StatelessWidget {
  final List<({DateTime dia, double receita, double lucro})> dias;
  const _ValoresPorDia({required this.dias});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: dias.map((d) {
          return Container(
            width: 92,
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${d.dia.day.toString().padLeft(2, '0')}/${d.dia.month.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.moeda(d.receita),
                  style: const TextStyle(color: AppColors.receita, fontSize: 11.5),
                ),
                Text(
                  Formatters.moeda(d.lucro),
                  style: const TextStyle(color: AppColors.lucro, fontSize: 11.5),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MetaDiaria extends StatelessWidget {
  const _MetaDiaria();

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConfiguracoesProvider, DashboardProvider>(
      builder: (context, configProvider, dashboardProvider, _) {
        final meta = configProvider.configuracoes.metaDiaria;
        if (meta <= 0) return const SizedBox.shrink();

        final receita = dashboardProvider.resumoPeriodo.receitaTotal;
        final progresso = (receita / meta).clamp(0.0, 1.0);
        final falta = (meta - receita).clamp(0, double.infinity);
        final atingiu = receita >= meta;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Meta diária',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${Formatters.moeda(receita)} / ${Formatters.moeda(meta)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progresso,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceElevated,
                  color: atingiu ? AppColors.receita : AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                atingiu
                    ? 'Meta batida! 🎉'
                    : 'Faltam ${Formatters.moeda(falta.toDouble())} para bater a meta',
                style: TextStyle(
                  color: atingiu ? AppColors.receita : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EstadoVazioGrafico extends StatelessWidget {
  const _EstadoVazioGrafico();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'Registre seus ganhos para ver o gráfico aqui',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ListaUltimosLancamentos extends StatelessWidget {
  final DashboardProvider provider;
  const _ListaUltimosLancamentos({required this.provider});

  @override
  Widget build(BuildContext context) {
    final itens = [
      ...provider.ultimasReceitas.map((r) => (
            data: r.data,
            titulo: 'Receita',
            valor: r.valorRecebido,
            positivo: true,
          )),
      ...provider.ultimasDespesas.map((d) => (
            data: d.data,
            titulo: d.categoria,
            valor: d.valor,
            positivo: false,
          )),
    ]..sort((a, b) => b.data.compareTo(a.data));

    if (itens.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Nenhum lançamento ainda',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: itens.take(6).map((item) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  item.positivo ? AppColors.receitaSoft : AppColors.despesaSoft,
              child: Icon(
                item.positivo ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: item.positivo ? AppColors.receita : AppColors.despesa,
                size: 18,
              ),
            ),
            title: Text(item.titulo, style: const TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              Formatters.data(item.data),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
            trailing: Text(
              '${item.positivo ? '+' : '-'} ${Formatters.moeda(item.valor)}',
              style: TextStyle(
                color: item.positivo ? AppColors.receita : AppColors.despesa,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
