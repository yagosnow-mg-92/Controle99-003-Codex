import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/configuracoes.dart';
import '../../providers/configuracoes_provider.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  final _formKey = GlobalKey<FormState>();

  final _modeloController = TextEditingController();
  final _anoController = TextEditingController();
  final _consumoController = TextEditingController();
  final _gasolinaController = TextEditingController();
  final _metaDiariaController = TextEditingController();
  final _metaSemanalController = TextEditingController();
  final _metaMensalController = TextEditingController();

  bool _preenchido = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ConfiguracoesProvider>().carregar();
      _preencherCampos();
    });
  }

  void _preencherCampos() {
    if (_preenchido || !mounted) return;
    final config = context.read<ConfiguracoesProvider>().configuracoes;

    _modeloController.text = config.motoModelo;
    _anoController.text = config.motoAno;
    _consumoController.text = config.consumoMedioKmL > 0 ? config.consumoMedioKmL.toString() : '';
    _gasolinaController.text = config.valorGasolina > 0 ? config.valorGasolina.toString() : '';
    _metaDiariaController.text = config.metaDiaria > 0 ? config.metaDiaria.toString() : '';
    _metaSemanalController.text = config.metaSemanal > 0 ? config.metaSemanal.toString() : '';
    _metaMensalController.text = config.metaMensal > 0 ? config.metaMensal.toString() : '';

    setState(() => _preenchido = true);
  }

  @override
  void dispose() {
    _modeloController.dispose();
    _anoController.dispose();
    _consumoController.dispose();
    _gasolinaController.dispose();
    _metaDiariaController.dispose();
    _metaSemanalController.dispose();
    _metaMensalController.dispose();
    super.dispose();
  }

  double _numero(String texto) => double.tryParse(texto.replaceAll(',', '.')) ?? 0;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final config = Configuracoes(
      motoModelo: _modeloController.text.trim(),
      motoAno: _anoController.text.trim(),
      consumoMedioKmL: _numero(_consumoController.text),
      valorGasolina: _numero(_gasolinaController.text),
      metaDiaria: _numero(_metaDiariaController.text),
      metaSemanal: _numero(_metaSemanalController.text),
      metaMensal: _numero(_metaMensalController.text),
    );

    await context.read<ConfiguracoesProvider>().salvar(config);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configurações salvas'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SafeArea(
        child: Consumer<ConfiguracoesProvider>(
          builder: (context, provider, _) {
            if (provider.carregando) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            // Garante que os campos sejam preenchidos assim que os dados
            // chegam, mesmo que o carregamento termine depois do primeiro build.
            WidgetsBinding.instance.addPostFrameCallback((_) => _preencherCampos());

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _secao(
                    titulo: 'Moto',
                    icone: Icons.two_wheeler_rounded,
                    children: [
                      _campoTexto(_modeloController, 'Modelo', hint: 'Ex: Honda CG 160'),
                      const SizedBox(height: 14),
                      _campoTexto(_anoController, 'Ano', hint: 'Ex: 2022'),
                      const SizedBox(height: 14),
                      _campoNumero(_consumoController, 'Consumo médio', sufixo: 'km/L'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _secao(
                    titulo: 'Combustível',
                    icone: Icons.local_gas_station_rounded,
                    children: [
                      _campoNumero(_gasolinaController, 'Valor atual da gasolina', prefixo: 'R\$ '),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _secao(
                    titulo: 'Metas',
                    icone: Icons.flag_rounded,
                    children: [
                      _campoNumero(_metaDiariaController, 'Meta diária', prefixo: 'R\$ '),
                      const SizedBox(height: 14),
                      _campoNumero(_metaSemanalController, 'Meta semanal', prefixo: 'R\$ '),
                      const SizedBox(height: 14),
                      _campoNumero(_metaMensalController, 'Meta mensal', prefixo: 'R\$ '),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.salvando ? null : _salvar,
                      child: provider.salvando
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Salvar configurações'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _secao({
    required String titulo,
    required IconData icone,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                titulo,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _campoTexto(TextEditingController controller, String label, {String? hint}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textDisabled),
      ),
    );
  }

  Widget _campoNumero(
    TextEditingController controller,
    String label, {
    String? prefixo,
    String? sufixo,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixText: prefixo,
        suffixText: sufixo,
      ),
    );
  }
}
