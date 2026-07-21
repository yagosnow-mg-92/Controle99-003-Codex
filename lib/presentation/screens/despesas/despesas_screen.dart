import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/despesa.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/despesa_provider.dart';

class DespesasScreen extends StatefulWidget {
  const DespesasScreen({super.key});

  @override
  State<DespesasScreen> createState() => _DespesasScreenState();
}

class _DespesasScreenState extends State<DespesasScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoriaController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _categoriaFocusNode = FocusNode();

  DateTime _dataSelecionada = DateTime.now();
  String _buscaTexto = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DespesaProvider>().carregar();
    });
  }

  @override
  void dispose() {
    _categoriaController.dispose();
    _valorController.dispose();
    _observacaoController.dispose();
    _categoriaFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final resultado = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(hoje.year, hoje.month, hoje.day),
      locale: const Locale('pt', 'BR'),
    );
    if (resultado != null) {
      setState(() => _dataSelecionada = resultado);
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = double.parse(_valorController.text.replaceAll(',', '.'));
    final categoria = _categoriaController.text.trim();

    final media = context.read<DespesaProvider>().mediaCategoria(categoria);
    if (media != null && valor > media * 1.5) {
      final continuar = await _confirmarDespesaElevada(valor: valor, media: media, categoria: categoria);
      if (!continuar) return;
    }

    await context.read<DespesaProvider>().salvar(
          data: _dataSelecionada,
          categoria: categoria,
          valor: valor,
          observacao: _observacaoController.text,
        );

    if (mounted) {
      await context.read<DashboardProvider>().carregar();
    }

    if (!mounted) return;

    _categoriaController.clear();
    _valorController.clear();
    _observacaoController.clear();
    // A data NÃO é resetada de propósito (ver mesmo comentário na tela de
    // Receita). A categoria é sempre limpa, já que cada despesa costuma
    // ser de um tipo diferente. Foco volta para o primeiro campo.
    FocusScope.of(context).requestFocus(_categoriaFocusNode);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Despesa lançada com sucesso'),
        backgroundColor: AppColors.despesa,
      ),
    );
  }

  Future<bool> _confirmarDespesaElevada({
    required double valor,
    required double media,
    required String categoria,
  }) async {
    final percentualAcima = ((valor / media) - 1) * 100;
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alerta),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Despesa acima do normal',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Essa despesa de ${Formatters.moeda(valor)} em "$categoria" está '
          '${percentualAcima.toStringAsFixed(0)}% acima da sua média nessa '
          'categoria (${Formatters.moeda(media)}). Quer salvar mesmo assim?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salvar mesmo assim', style: TextStyle(color: AppColors.alerta)),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  Future<bool> _confirmarExclusao(Despesa despesa) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Excluir lançamento?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '${despesa.categoria} de ${Formatters.moeda(despesa.valor)} do dia '
          '${Formatters.data(despesa.data)} será excluída permanentemente.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.despesa)),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançar despesa')),
      body: SafeArea(
        child: Consumer<DespesaProvider>(
          builder: (context, provider, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _formulario(provider),
                const SizedBox(height: 28),
                const Text(
                  'Despesas recentes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _campoBusca(),
                const SizedBox(height: 12),
                _listaLancamentos(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _formulario(DespesaProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _campoData(),
            const SizedBox(height: 14),
            _campoCategoria(provider),
            const SizedBox(height: 14),
            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Valor',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixText: 'R\$ ',
              ),
              validator: (valor) {
                final numero = double.tryParse((valor ?? '').replaceAll(',', '.'));
                if (numero == null || numero <= 0) return 'Informe um valor válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _observacaoController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.salvando ? null : _salvar,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.despesa),
                child: provider.salvando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Salvar despesa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoData() {
    return InkWell(
      onTap: _selecionarData,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              Formatters.data(_dataSelecionada),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  /// Campo de categoria com liberdade total de digitação, mas sugerindo
  /// (via Autocomplete) as categorias já utilizadas anteriormente —
  /// atende ao requisito de "sem despesas fixas, com reaproveitamento".
  Widget _campoCategoria(DespesaProvider provider) {
    return RawAutocomplete<String>(
      textEditingController: _categoriaController,
      focusNode: _categoriaFocusNode,
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) return provider.categorias;
        return provider.categorias.where(
          (categoria) => categoria.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      onSelected: (selecionada) => _categoriaController.text = selecionada,
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Categoria',
            labelStyle: TextStyle(color: AppColors.textSecondary),
            hintText: 'Ex: Gasolina, Manutenção...',
            hintStyle: TextStyle(color: AppColors.textDisabled),
          ),
          validator: (valor) {
            if (valor == null || valor.trim().isEmpty) return 'Informe uma categoria';
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opcao = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(opcao, style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () => onSelected(opcao),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _campoBusca() {
    return TextField(
      onChanged: (texto) => setState(() => _buscaTexto = texto),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        hintText: 'Buscar por categoria, valor ou observação...',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _listaLancamentos(DespesaProvider provider) {
    if (provider.carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final busca = _buscaTexto.trim().toLowerCase();
    final lancamentosFiltrados = busca.isEmpty
        ? provider.lancamentos
        : provider.lancamentos.where((d) {
            return d.categoria.toLowerCase().contains(busca) ||
                d.valor.toString().contains(busca) ||
                (d.observacao ?? '').toLowerCase().contains(busca);
          }).toList();

    if (lancamentosFiltrados.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          busca.isEmpty ? 'Nenhuma despesa lançada ainda' : 'Nenhum resultado para "$_buscaTexto"',
          style: const TextStyle(color: AppColors.textSecondary),
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
        children: lancamentosFiltrados.map((d) {
          return Dismissible(
            key: ValueKey(d.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmarExclusao(d),
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.despesa.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.despesa),
            ),
            onDismissed: (_) async {
              await context.read<DespesaProvider>().excluir(d.id);
              if (context.mounted) {
                await context.read<DashboardProvider>().carregar();
              }
            },
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.despesaSoft,
                child: Icon(Icons.arrow_downward_rounded, color: AppColors.despesa, size: 18),
              ),
              title: Text(
                d.categoria,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                Formatters.data(d.data),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              trailing: Text(
                '- ${Formatters.moeda(d.valor)}',
                style: const TextStyle(color: AppColors.despesa, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
