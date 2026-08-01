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
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _IndicadorGanhoPorKmElevado(provider: provider)),
                        const SizedBox(width: 12),
                        Expanded(child: _IndicadorCorridasElevado(provider: provider)),
                      ],
                    ),
                  ),
                  const _CarrosselMetas(),
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

/// Gráfico da receita dos últimos 7 dias — desenhado do zero (sem
/// biblioteca de gráficos) pra ter controle total sobre a animação de
/// entrada e deixar valor + dia sempre legíveis, sem precisar tocar.
///
/// Cada barra sobe do zero com um leve atraso em cascata (efeito onda),
/// o dia de hoje ganha destaque próprio (contorno e brilho), e tocar numa
/// barra dá um pequeno "salto" nela — pra dar uma sensação viva ao gráfico
/// mesmo sem esconder nenhuma informação atrás do toque.
class _GraficoDesempenho extends StatefulWidget {
  final DashboardProvider provider;
  const _GraficoDesempenho({required this.provider});

  @override
  State<_GraficoDesempenho> createState() => _GraficoDesempenhoState();
}

class _GraficoDesempenhoState extends State<_GraficoDesempenho> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int? _indiceTocado;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _diasSemana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

  @override
  Widget build(BuildContext context) {
    final dias = widget.provider.ultimos7Dias;
    if (dias.isEmpty || dias.every((d) => d.receita == 0)) {
      return const _EstadoVazioGrafico();
    }

    final maiorValor = dias.map((d) => d.receita).fold<double>(0, (a, b) => a > b ? a : b);
    final hoje = DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(dias.length, (i) {
            final dia = dias[i];
            final ehHoje = dia.dia.year == hoje.year && dia.dia.month == hoje.month && dia.dia.day == hoje.day;
            final fracao = maiorValor == 0 ? 0.0 : dia.receita / maiorValor;

            // Cascata: cada barra começa sua animação um pouco depois da
            // anterior, criando a sensação de "onda subindo" ao abrir a tela.
            final inicioAtraso = (i / dias.length) * 0.5;
            final curvaBarra = CurvedAnimation(
              parent: _controller,
              curve: Interval(inicioAtraso, (inicioAtraso + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
            );

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _indiceTocado = i),
                onTapUp: (_) => setState(() => _indiceTocado = null),
                onTapCancel: () => setState(() => _indiceTocado = null),
                child: AnimatedBuilder(
                  animation: curvaBarra,
                  builder: (context, child) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Opacity(
                          opacity: curvaBarra.value,
                          child: Text(
                            dia.receita == 0 ? '—' : _valorCompacto(dia.receita),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              color: ehHoje ? AppColors.receita : AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: ehHoje ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedScale(
                          duration: const Duration(milliseconds: 120),
                          scale: _indiceTocado == i ? 1.08 : 1.0,
                          child: Container(
                            height: 130 * fracao * curvaBarra.value,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            constraints: const BoxConstraints(minHeight: 4),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: ehHoje
                                    ? [AppColors.receita, AppColors.receita.withOpacity(0.55)]
                                    : [AppColors.receita.withOpacity(0.55), AppColors.receita.withOpacity(0.18)],
                              ),
                              boxShadow: ehHoje
                                  ? [BoxShadow(color: AppColors.receita.withOpacity(0.45), blurRadius: 12, offset: const Offset(0, 4))]
                                  : null,
                              border: ehHoje ? Border.all(color: AppColors.receita, width: 1.5) : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: curvaBarra.value,
                          child: Column(
                            children: [
                              Text(
                                '${dia.dia.day}',
                                style: TextStyle(
                                  color: ehHoje ? AppColors.textPrimary : AppColors.textSecondary,
                                  fontSize: 12.5,
                                  fontWeight: ehHoje ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              Text(
                                ehHoje ? 'hoje' : _diasSemana[dia.dia.weekday - 1],
                                style: TextStyle(
                                  color: ehHoje ? AppColors.receita : AppColors.textDisabled,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  String _valorCompacto(double valor) {
    if (valor.abs() >= 1000) return '${(valor / 1000).toStringAsFixed(1)}k';
    return valor.round().toString();
  }
}

/// Indicador "Meta diária" — estilo Barra de fundo do catálogo (`.bgbar`):
/// o preenchimento de progresso ocupa o card inteiro atrás do texto, ao
/// invés de uma barrinha fina embaixo. Só aparece se uma meta diária foi
/// configurada, e sempre usa a receita de HOJE — nunca muda com o filtro
/// de período do painel, porque "diária" é diária, ponto final.
/// Um "cartão de meta": diária, semanal ou mensal — todos com o mesmo
/// visual de barra de fundo (`.bgbar` do catálogo) já usado no indicador
/// original. Extraído como widget próprio pra ser reaproveitado pelas três
/// páginas do carrossel abaixo.
class _CartaoMeta extends StatelessWidget {
  final String rotulo;
  final double valor;
  final double meta;

  const _CartaoMeta({required this.rotulo, required this.valor, required this.meta});

  @override
  Widget build(BuildContext context) {
    final progresso = (valor / meta).clamp(0.0, 1.0);
    final percentual = (progresso * 100).round();
    final atingiu = valor >= meta;
    final cor = atingiu ? AppColors.receita : AppColors.primary;

    return Container(
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
                      colors: [cor.withOpacity(0.28), cor.withOpacity(0.05)],
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rotulo,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text: Formatters.moeda(valor),
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
                  style: TextStyle(color: cor, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carrossel de metas — diária, semanal e mensal, cada uma no mesmo visual
/// de barra de fundo, arrastável horizontalmente. Só entram no carrossel as
/// metas que o motociclista configurou (valor > 0); se nenhuma estiver
/// configurada, o carrossel inteiro fica oculto — igual o comportamento
/// original, só que agora por meta individual.
class _CarrosselMetas extends StatefulWidget {
  const _CarrosselMetas();

  @override
  State<_CarrosselMetas> createState() => _CarrosselMetasState();
}

class _CarrosselMetasState extends State<_CarrosselMetas> {
  final _controller = PageController(viewportFraction: 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConfiguracoesProvider, DashboardProvider>(
      builder: (context, configProvider, dashboardProvider, _) {
        final config = configProvider.configuracoes;
        final metas = <({String rotulo, double valor, double meta})>[
          if (config.metaDiaria > 0)
            (rotulo: 'Meta diária', valor: dashboardProvider.receitaHoje, meta: config.metaDiaria),
          if (config.metaSemanal > 0)
            (rotulo: 'Meta semanal', valor: dashboardProvider.receitaSemana, meta: config.metaSemanal),
          if (config.metaMensal > 0)
            (rotulo: 'Meta mensal', valor: dashboardProvider.receitaMes, meta: config.metaMensal),
        ];
        if (metas.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: metas.length == 1
                    ? _CartaoMeta(rotulo: metas.first.rotulo, valor: metas.first.valor, meta: metas.first.meta)
                    : AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          return PageView.builder(
                            controller: _controller,
                            itemCount: metas.length,
                            itemBuilder: (context, index) {
                              // Efeito carrossel: a página central fica em
                              // tamanho e opacidade máximos, e as vizinhas
                              // encolhem/apagam levemente conforme se afastam
                              // — o mesmo tipo de transição suave usado em
                              // carrosséis de apps como o de saúde da Apple.
                              double diferenca = index.toDouble();
                              if (_controller.hasClients && _controller.position.haveDimensions) {
                                diferenca = (index - (_controller.page ?? _controller.initialPage.toDouble()));
                              }
                              final proximidade = (1 - diferenca.abs().clamp(0.0, 1.0));
                              final escala = 0.94 + (0.06 * proximidade);
                              final opacidade = 0.6 + (0.4 * proximidade);

                              final meta = metas[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: Opacity(
                                  opacity: opacidade,
                                  child: Transform.scale(
                                    scale: escala,
                                    child: _CartaoMeta(rotulo: meta.rotulo, valor: meta.valor, meta: meta.meta),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              if (metas.length > 1) ...[
                const SizedBox(height: 10),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final paginaAtual = _controller.hasClients && _controller.position.haveDimensions
                        ? (_controller.page ?? 0.0)
                        : 0.0;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(metas.length, (index) {
                        final distancia = (paginaAtual - index).abs().clamp(0.0, 1.0);
                        final ativo = 1 - distancia;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6 + (10 * ativo),
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Color.lerp(AppColors.border, AppColors.primary, ativo),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ],
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
