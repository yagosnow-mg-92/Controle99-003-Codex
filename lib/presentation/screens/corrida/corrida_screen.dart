import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/status_sessao.dart';
import '../../providers/corrida_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/receita_provider.dart';

class CorridaScreen extends StatefulWidget {
  const CorridaScreen({super.key});

  @override
  State<CorridaScreen> createState() => _CorridaScreenState();
}

class _CorridaScreenState extends State<CorridaScreen> {
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<CorridaProvider>().inicializar();
      if (mounted) setState(() => _inicializado = true);
    });
  }

  Future<double?> _pedirValor({
    required String titulo,
    required String mensagem,
    double? valorInicial,
  }) async {
    final controller = TextEditingController(
      text: valorInicial != null ? valorInicial.toStringAsFixed(2) : '',
    );
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(titulo, style: const TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mensagem,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
              decoration: const InputDecoration(prefixText: 'R\$ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final valor = double.tryParse(controller.text.replaceAll(',', '.'));
              if (valor == null || valor <= 0) return;
              Navigator.of(context).pop(valor);
            },
            child: const Text('Confirmar', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  String _formatarDuracao(Duration d) {
    final horas = d.inHours.toString().padLeft(2, '0');
    final minutos = (d.inMinutes % 60).toString().padLeft(2, '0');
    final segundos = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$horas:$minutos:$segundos' : '$minutos:$segundos';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corrida')),
      body: SafeArea(
        child: !_inicializado
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Consumer<CorridaProvider>(
                builder: (context, provider, _) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (provider.erro != null) _AvisoErro(mensagem: provider.erro!),
                        Expanded(child: Center(child: _conteudoPorStatus(provider))),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _conteudoPorStatus(CorridaProvider provider) {
    switch (provider.status) {
      case StatusSessao.offline:
        return _TelaOffline(provider: provider);
      case StatusSessao.online:
        return _TelaOnline(
          provider: provider,
          formatarDuracao: _formatarDuracao,
          onIniciarCorrida: () async {
            final valor = await _pedirValor(
              titulo: 'Valor da corrida',
              mensagem: 'Informe o valor combinado para essa corrida.',
            );
            if (valor != null) await provider.iniciarCorrida(valor);
          },
          onFicarOffline: () async {
            await provider.ficarOffline();
            await _atualizarReceitaEDashboard();
          },
        );
      case StatusSessao.corridaIniciada:
        return _TelaCorridaIniciada(
          provider: provider,
          formatarDuracao: _formatarDuracao,
          onCancelar: () async {
            final valor = await _pedirValor(
              titulo: 'Cancelar corrida',
              mensagem: 'Informe o valor da taxa de deslocamento (geralmente diferente do valor da corrida).',
              valorInicial: provider.corridaAtual?.valor,
            );
            if (valor != null) {
              await provider.cancelarCorrida(valor);
              await _atualizarReceitaEDashboard();
            }
          },
          onPegarPassageiro: provider.pegarPassageiro,
        );
      case StatusSessao.comPassageiro:
        return _TelaComPassageiro(
          provider: provider,
          formatarDuracao: _formatarDuracao,
          onFinalizar: () async {
            await provider.finalizarCorrida();
            await _atualizarReceitaEDashboard();
          },
        );
    }
  }

  /// A Corrida lança receitas automaticamente (ao finalizar ou cancelar),
  /// mas isso acontece por fora das telas de Receita/Painel — elas
  /// precisam ser avisadas pra recarregar, senão o lançamento novo só
  /// aparece depois que o app for reaberto.
  Future<void> _atualizarReceitaEDashboard() async {
    if (!mounted) return;
    await context.read<ReceitaProvider>().carregar();
    if (!mounted) return;
    await context.read<DashboardProvider>().carregar();
  }
}

class _AvisoErro extends StatelessWidget {
  final String mensagem;
  const _AvisoErro({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.despesaSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.despesa, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(mensagem, style: const TextStyle(color: AppColors.despesa, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _TelaOffline extends StatelessWidget {
  final CorridaProvider provider;
  const _TelaOffline({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.two_wheeler_rounded, size: 56, color: AppColors.textDisabled),
        ),
        const SizedBox(height: 24),
        const Text(
          'Você está offline',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Fique online para começar a rastrear seu tempo e localização.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.processando ? null : provider.ficarOnline,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.receita,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: provider.processando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Ficar online', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

class _CabecalhoStatus extends StatelessWidget {
  final String titulo;
  final Color cor;
  final Duration tempo;
  final String Function(Duration) formatarDuracao;
  final String? endereco;

  const _CabecalhoStatus({
    required this.titulo,
    required this.cor,
    required this.tempo,
    required this.formatarDuracao,
    this.endereco,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: cor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
          child: Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const SizedBox(height: 20),
        Text(
          formatarDuracao(tempo),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        if (endereco != null && endereco!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded, color: AppColors.textSecondary, size: 15),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    endereco!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TelaOnline extends StatelessWidget {
  final CorridaProvider provider;
  final String Function(Duration) formatarDuracao;
  final VoidCallback onIniciarCorrida;
  final VoidCallback onFicarOffline;

  const _TelaOnline({
    required this.provider,
    required this.formatarDuracao,
    required this.onIniciarCorrida,
    required this.onFicarOffline,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CabecalhoStatus(
          titulo: 'ONLINE · Procurando corrida',
          cor: AppColors.primary,
          tempo: provider.tempoDecorrido,
          formatarDuracao: formatarDuracao,
          endereco: provider.enderecoAtual,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.processando ? null : onIniciarCorrida,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            child: const Text('Iniciar corrida', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: provider.processando ? null : onFicarOffline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: AppColors.border),
            ),
            child: const Text('Ficar offline', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }
}

class _TelaCorridaIniciada extends StatelessWidget {
  final CorridaProvider provider;
  final String Function(Duration) formatarDuracao;
  final VoidCallback onCancelar;
  final VoidCallback onPegarPassageiro;

  const _TelaCorridaIniciada({
    required this.provider,
    required this.formatarDuracao,
    required this.onCancelar,
    required this.onPegarPassageiro,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CabecalhoStatus(
          titulo: 'CORRIDA INICIADA',
          cor: AppColors.alerta,
          tempo: provider.tempoDecorrido,
          formatarDuracao: formatarDuracao,
          endereco: provider.enderecoAtual,
        ),
        const SizedBox(height: 8),
        Text(
          'Valor: ${Formatters.moeda(provider.corridaAtual?.valor ?? 0)}',
          style: const TextStyle(color: AppColors.receita, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.processando ? null : onPegarPassageiro,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.receita,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
            child: const Text('Peguei o passageiro', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: provider.processando ? null : onCancelar,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              side: const BorderSide(color: AppColors.despesa),
            ),
            child: const Text('Cancelar corrida', style: TextStyle(color: AppColors.despesa)),
          ),
        ),
      ],
    );
  }
}

class _TelaComPassageiro extends StatelessWidget {
  final CorridaProvider provider;
  final String Function(Duration) formatarDuracao;
  final VoidCallback onFinalizar;

  const _TelaComPassageiro({
    required this.provider,
    required this.formatarDuracao,
    required this.onFinalizar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CabecalhoStatus(
          titulo: 'COM PASSAGEIRO A BORDO',
          cor: AppColors.receita,
          tempo: provider.tempoDecorrido,
          formatarDuracao: formatarDuracao,
          endereco: provider.enderecoAtual,
        ),
        const SizedBox(height: 8),
        Text(
          'Valor: ${Formatters.moeda(provider.corridaAtual?.valor ?? 0)}',
          style: const TextStyle(color: AppColors.receita, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: provider.processando ? null : onFinalizar,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            child: const Text('Finalizar corrida', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}
