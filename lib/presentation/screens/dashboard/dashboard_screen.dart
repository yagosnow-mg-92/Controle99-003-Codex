import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/filtro_lancamentos.dart';
import '../../../domain/entities/periodo_filtro.dart';
import '../../providers/configuracoes_provider.dart';
import '../../providers/dashboard_provider.dart';


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

  Future<void> _abrirFiltros(DashboardProvider provider) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              // Em telas com a barra de navegação do Android, os filtros
              // continuam acima dela e o conteúdo pode ser rolado.
              maxHeight: MediaQuery.sizeOf(context).height * 0.80,
            ),
            child: SingleChildScrollView(
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
                Padding(
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
                      style: TextStyle(color: AppColors.textPrimary),
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
                  title: Text(
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
                Divider(color: AppColors.border, height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Exibir lançamentos:',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final opcao in FiltroLancamentos.values)
                  ListTile(
                    leading: Icon(
                      provider.filtroLancamentos == opcao
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: provider.filtroLancamentos == opcao
                          ? AppColors.primary
                          : AppColors.textDisabled,
                    ),
                    title: Text(
                      opcao.descricao,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await provider.mudarFiltroLancamentos(opcao);
                    },
                  ),
              ],
            ),
              ),
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
              return Center(
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
                    onTapFiltros: () => _abrirFiltros(provider),
                  ),
                  const SizedBox(height: 20),
                  _IndicadorReceitaNeon(provider: provider),
                  const SizedBox(height: 12),
                  _IndicadorKmVidro(provider: provider),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _IndicadorGanhoPorKmElevado(provider: provider)),
                      const SizedBox(width: 12),
                      Expanded(child: _IndicadorCorridasElevado(provider: provider)),
                    ],
                  ),
                  const _MetaDiariaBarraFundo(),
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
  final VoidCallback onTapFiltros;

  const _Cabecalho({required this.provider, required this.onTapFiltros});

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
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
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
          onTap: onTapFiltros,
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
                  'Filtros',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
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
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Indicador "Receita" — estilo Neon do catálogo (`.neon-card`): fundo
/// escuro com borda e brilho verde ao redor, para dar destaque ao número
/// mais importante do painel. Soma todos os lançamentos de receita
/// (corrida, deslocamento livre e manual) dentro do período filtrado.
class _IndicadorReceitaNeon extends StatelessWidget {
  final DashboardProvider provider;
  const _IndicadorReceitaNeon({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.receita.withOpacity(0.45), width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.receita.withOpacity(0.28), blurRadius: 24),
          BoxShadow(color: AppColors.receita.withOpacity(0.15), blurRadius: 6, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Receita',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.moeda(provider.resumoPeriodo.receitaTotal),
            style: TextStyle(color: AppColors.receita, fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Indicador "Ganhos por Km" — estilo Elevado (3D) do catálogo (`.elevado`):
/// gradiente sutil de cima pra baixo e sombra em camadas, sem cor de
/// destaque, dando sensação de "flutuar" sobre o fundo. Valor bruto:
/// receita total dividida pelo km total (corrida + deslocamento livre),
/// sem descontar despesa — respeitando o filtro do painel.
class _IndicadorGanhoPorKmElevado extends StatelessWidget {
  final DashboardProvider provider;
  const _IndicadorGanhoPorKmElevado({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ganhos por Km',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.moeda(provider.resumoPeriodo.receitaPorKm),
            style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Indicador "Corridas" — mesmo estilo Elevado (3D), lado a lado com
/// "Ganhos por Km" (por isso não usa `width: double.infinity`: o pai já é
/// um `Expanded` dentro de uma `Row`, que define a largura). Conta só
/// corridas de verdade — deslocamento livre não entra — dentro do mesmo
/// período filtrado que os outros indicadores.
class _IndicadorCorridasElevado extends StatelessWidget {
  final DashboardProvider provider;
  const _IndicadorCorridasElevado({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceElevated, AppColors.surface],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: -12,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Corridas',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            '${provider.quantidadeCorridas}',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Indicador "Total de km rodados" — estilo Vidro + marca d'água do
/// catálogo (`.glass`): fundo translúcido com gradiente e um ícone gigante
/// apagado no canto. Soma o km de todos os lançamentos de receita
/// (corrida e deslocamento livre) dentro do período filtrado.
class _IndicadorKmVidro extends StatelessWidget {
  final DashboardProvider provider;
  const _IndicadorKmVidro({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.textPrimary.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary.withOpacity(0.14), AppColors.surface],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.two_wheeler_rounded,
              size: 90,
              color: AppColors.textPrimary.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total de km rodados',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  Formatters.km(provider.resumoPeriodo.kmRodados),
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GraficoDesempenho extends StatelessWidget {
  final DashboardProvider provider;
  const _GraficoDesempenho({required this.provider});

  @override
  Widget build(BuildContext context) {
    final dias = provider.ultimos7Dias;

    if (dias.isEmpty || dias.every((d) => d.receita == 0)) {
      return const _EstadoVazioGrafico();
    }

    final maiorValor = dias.map((d) => d.receita).fold<double>(0, (a, b) => a > b ? a : b);

    final maxY = maiorValor == 0 ? 10.0 : maiorValor * 1.25;
    const minY = 0.0;
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
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _linha(dias.map((d) => d.receita).toList(), AppColors.receita),
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
    return _ItemLegenda(cor: AppColors.receita, texto: 'Receita');
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
        Text(texto, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
                  style: TextStyle(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Formatters.moeda(d.receita),
                  style: TextStyle(color: AppColors.receita, fontSize: 11.5),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Indicador "Meta diária" — estilo Barra de fundo do catálogo (`.bgbar`):
/// o preenchimento de progresso ocupa o card inteiro atrás do texto, ao
/// invés de uma barrinha fina embaixo. Só aparece se uma meta diária foi
/// configurada, e sempre usa a receita de HOJE — nunca muda com o filtro
/// de período do painel, porque "diária" é diária, ponto final.
class _MetaDiariaBarraFundo extends StatelessWidget {
  const _MetaDiariaBarraFundo();

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConfiguracoesProvider, DashboardProvider>(
      builder: (context, configProvider, dashboardProvider, _) {
        final meta = configProvider.configuracoes.metaDiaria;
        if (meta <= 0) return const SizedBox.shrink();

        final receita = dashboardProvider.receitaHoje;
        final progresso = (receita / meta).clamp(0.0, 1.0);
        final percentual = (progresso * 100).round();
        final atingiu = receita >= meta;

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: double.infinity,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progresso == 0 ? 0.0001 : progresso,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              (atingiu ? AppColors.receita : AppColors.primary).withOpacity(0.28),
                              (atingiu ? AppColors.receita : AppColors.primary).withOpacity(0.05),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meta diária',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          text: Formatters.moeda(receita),
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                          children: [
                            TextSpan(
                              text: ' / ${Formatters.moeda(meta)}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        atingiu ? 'Meta batida! 🎉' : '$percentual% concluído',
                        style: TextStyle(
                          color: atingiu ? AppColors.receita : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
      child: Text(
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
            titulo: r.tipo.descricao,
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
        child: Text(
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
            title: Text(item.titulo, style: TextStyle(color: AppColors.textPrimary)),
            subtitle: Text(
              Formatters.data(item.data),
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
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
