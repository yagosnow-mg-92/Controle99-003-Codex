import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/filtro_lancamentos.dart';
import '../../../domain/entities/receita.dart';
import '../../../domain/repositories/corrida_repository.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/receita_provider.dart';
import 'mapa_trajeto_screen.dart';

class ReceitaScreen extends StatefulWidget {
  const ReceitaScreen({super.key});

  @override
  State<ReceitaScreen> createState() => _ReceitaScreenState();
}

class _ReceitaScreenState extends State<ReceitaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _embarqueController = TextEditingController();
  final _destinoController = TextEditingController();
  final _kmFocusNode = FocusNode();
  final _scrollController = ScrollController();

  DateTime _dataSelecionada = DateTime.now();
  double _valorPorKmPreview = 0;
  String _buscaTexto = '';
  TipoReceita _tipoSelecionado = TipoReceita.outro;

  /// Quando não-nulo, o formulário está mostrando um lançamento já
  /// existente (aberto com duplo toque na lista), em vez de um novo.
  String? _idEmVisualizacao;

  /// O lançamento completo sendo visualizado — usado pra saber o tipo
  /// (corrida/deslocamento/manual) e habilitar o botão de mapa.
  Receita? _receitaEmVisualizacao;

  /// Enquanto true, os campos ficam travados (só leitura) — precisa
  /// tocar em "Editar" pra poder alterar algo.
  bool _somenteLeitura = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceitaProvider>().carregar();
    });
    _kmController.addListener(_atualizarPreview);
    _valorController.addListener(_atualizarPreview);
  }

  @override
  void dispose() {
    _kmController.dispose();
    _valorController.dispose();
    _observacaoController.dispose();
    _embarqueController.dispose();
    _destinoController.dispose();
    _kmFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _atualizarPreview() {
    final km = double.tryParse(_kmController.text.replaceAll(',', '.')) ?? 0;
    final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      _valorPorKmPreview = km > 0 ? valor / km : 0;
    });
  }

  /// Duplo toque num lançamento da lista: preenche o formulário lá em
  /// cima com os dados dele (em modo só-leitura) e rola a tela até lá,
  /// como se o usuário tivesse acabado de digitar tudo.
  void _visualizarLancamento(Receita r) {
    _kmController.text = r.kmRodados.toString();
    _valorController.text = r.valorRecebido.toString();
    _observacaoController.text = r.observacao ?? '';
    _embarqueController.text = r.localEmbarque ?? '';
    _destinoController.text = r.localDestino ?? '';

    final km = double.tryParse(r.kmRodados.toString()) ?? 0;
    final valor = r.valorRecebido;

    setState(() {
      _dataSelecionada = r.data;
      _idEmVisualizacao = r.id;
      _receitaEmVisualizacao = r;
      _somenteLeitura = true;
      _valorPorKmPreview = km > 0 ? valor / km : 0;
      _tipoSelecionado = r.tipo;
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _habilitarEdicao() {
    setState(() => _somenteLeitura = false);
  }

  /// Sai do modo visualização/edição e volta pro estado de "novo
  /// lançamento", limpando tudo.
  void _cancelarVisualizacao() {
    _kmController.clear();
    _valorController.clear();
    _observacaoController.clear();
    _embarqueController.clear();
    _destinoController.clear();
    setState(() {
      _dataSelecionada = DateTime.now();
      _idEmVisualizacao = null;
      _receitaEmVisualizacao = null;
      _somenteLeitura = false;
      _valorPorKmPreview = 0;
      _tipoSelecionado = TipoReceita.outro;
    });
  }

  Future<void> _selecionarData() async {
    if (_somenteLeitura) return;
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

    final km = double.parse(_kmController.text.replaceAll(',', '.'));
    final valor = double.parse(_valorController.text.replaceAll(',', '.'));
    final editando = _idEmVisualizacao != null;

    await context.read<ReceitaProvider>().salvar(
          id: _idEmVisualizacao,
          data: _dataSelecionada,
          kmRodados: km,
          valorRecebido: valor,
          observacao: _observacaoController.text,
          localEmbarque: _embarqueController.text,
          localDestino: _destinoController.text,
          tipo: _tipoSelecionado,
        );

    // Mantém os providers em sincronia: assim que uma receita é salva,
    // o Dashboard recalcula seus indicadores automaticamente.
    if (mounted) {
      await context.read<DashboardProvider>().carregar();
    }

    if (!mounted) return;

    _kmController.clear();
    _valorController.clear();
    _observacaoController.clear();
    _embarqueController.clear();
    _destinoController.clear();
    setState(() {
      _valorPorKmPreview = 0;
      _idEmVisualizacao = null;
      _somenteLeitura = false;
      _tipoSelecionado = TipoReceita.outro;
      // Ao editar um lançamento, volta pra data de hoje (o contexto
      // mudou). Ao criar um novo, mantém a data — ver comentário abaixo.
      if (editando) _dataSelecionada = DateTime.now();
    });
    // A data NÃO é resetada em lançamentos novos, de propósito: ao
    // lançar vários dias retroativos seguidos, o usuário espera
    // continuar no mesmo dia até trocar manualmente. O foco volta para
    // o primeiro campo (Km), agilizando o próximo lançamento.
    FocusScope.of(context).requestFocus(_kmFocusNode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(editando ? 'Lançamento atualizado com sucesso' : 'Receita lançada com sucesso'),
        backgroundColor: AppColors.receita,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançar receita')),
      body: SafeArea(
        child: Consumer<ReceitaProvider>(
          builder: (context, provider, _) {
            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _formulario(provider),
                const SizedBox(height: 28),
                const Text(
                  'Lançamentos recentes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Toque duas vezes num lançamento para ver ou editar',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

  Widget _formulario(ReceitaProvider provider) {
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
            if (_idEmVisualizacao != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _somenteLeitura ? Icons.visibility_rounded : Icons.edit_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _somenteLeitura ? 'Visualizando lançamento' : 'Editando lançamento',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _cancelarVisualizacao,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (_receitaEmVisualizacao?.horaInicio != null &&
                _receitaEmVisualizacao?.horaFim != null) ...[
              _cardDuracao(_receitaEmVisualizacao!),
              const SizedBox(height: 14),
            ],
            _campoData(),
            const SizedBox(height: 14),
            DropdownButtonFormField<TipoReceita>(
              value: _tipoSelecionado,
              decoration: const InputDecoration(
                labelText: 'Tipo de lançamento',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              dropdownColor: AppColors.surfaceElevated,
              style: const TextStyle(color: AppColors.textPrimary),
              items: TipoReceita.values
                  .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo.descricao)))
                  .toList(),
              onChanged: _somenteLeitura ? null : (tipo) {
                if (tipo != null) setState(() => _tipoSelecionado = tipo);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _kmController,
              focusNode: _kmFocusNode,
              enabled: !_somenteLeitura,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Quilômetros rodados',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                suffixText: 'km',
              ),
              validator: (valor) {
                final numero = double.tryParse((valor ?? '').replaceAll(',', '.'));
                if (numero == null || numero <= 0) return 'Informe um valor de km válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _valorController,
              enabled: !_somenteLeitura,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Valor recebido',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixText: 'R\$ ',
              ),
              validator: (valor) {
                final numero = double.tryParse((valor ?? '').replaceAll(',', '.'));
                if (numero == null || numero < 0) return 'Informe um valor recebido válido';
                if (_tipoSelecionado != TipoReceita.deslocamentoLivre && numero == 0) {
                  return 'Informe um valor recebido válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _observacaoController,
              enabled: !_somenteLeitura,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _embarqueController,
              enabled: !_somenteLeitura,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Local de embarque (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.trip_origin_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _destinoController,
              enabled: !_somenteLeitura,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Local de destino (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 16),
            _previewValorPorKm(),
            const SizedBox(height: 18),
            _botoesAcao(provider),
          ],
        ),
      ),
    );
  }

  Widget _cardDuracao(Receita r) {
    final duracao = r.horaFim!.difference(r.horaInicio!);
    final horaFormatada = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${horaFormatada.format(r.horaInicio!)} até ${horaFormatada.format(r.horaFim!)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            Formatters.duracao(duracao),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirMapa() async {
    final receita = _receitaEmVisualizacao;
    if (receita == null || !receita.temTrajetoGps) return;

    final repository = context.read<CorridaRepository>();
    final pontos = receita.tipo == TipoReceita.corrida
        ? await repository.pontosDaCorridaPorReceita(receita.id)
        : await repository.pontosDoDeslocamentoPorReceita(receita.id);

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapaTrajetoScreen(
          pontos: pontos,
          titulo: receita.tipo == TipoReceita.corrida ? 'Trajeto da corrida' : 'Trajeto do deslocamento',
        ),
      ),
    );
  }

  Widget _botoesAcao(ReceitaProvider provider) {
    // Visualizando (ainda travado): "Ver mapa" (se tiver trajeto de GPS) + "Editar".
    if (_idEmVisualizacao != null && _somenteLeitura) {
      final temMapa = _receitaEmVisualizacao?.temTrajetoGps ?? false;
      return Column(
        children: [
          if (temMapa) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _abrirMapa,
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Ver mapa do trajeto'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.lucro,
                  side: const BorderSide(color: AppColors.lucro),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _habilitarEdicao,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      );
    }

    // Editando um lançamento existente: "Salvar alterações" + "Cancelar".
    if (_idEmVisualizacao != null && !_somenteLeitura) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: provider.salvando ? null : _cancelarVisualizacao,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: provider.salvando ? null : _salvar,
              child: provider.salvando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar alterações'),
            ),
          ),
        ],
      );
    }

    // Novo lançamento (comportamento padrão).
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: provider.salvando ? null : _salvar,
        child: provider.salvando
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Salvar receita'),
      ),
    );
  }

  Widget _campoData() {
    return InkWell(
      onTap: _selecionarData,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: _somenteLeitura ? 0.6 : 1,
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
      ),
    );
  }

  Widget _previewValorPorKm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.receitaSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Valor por Km',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            Formatters.moeda(_valorPorKmPreview),
            style: const TextStyle(
              color: AppColors.receita,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarExclusao(Receita receita) async {
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
          'Receita de ${Formatters.moeda(receita.valorRecebido)} do dia ${Formatters.data(receita.data)} será excluída permanentemente.',
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

  Widget _campoBusca() {
    return TextField(
      onChanged: (texto) => setState(() => _buscaTexto = texto),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        hintText: 'Buscar por valor, km ou observação...',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _listaLancamentos(ReceitaProvider provider) {
    if (provider.carregando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final filtroLancamentos = context.watch<DashboardProvider>().filtroLancamentos;
    final lancamentosDoFiltroGlobal = provider.lancamentos.where((r) {
      return filtroLancamentos == FiltroLancamentos.todos || r.tipo == TipoReceita.corrida;
    });
    final busca = _buscaTexto.trim().toLowerCase();
    final lancamentosFiltrados = busca.isEmpty
        ? lancamentosDoFiltroGlobal.toList()
        : lancamentosDoFiltroGlobal.where((r) {
            return r.valorRecebido.toString().contains(busca) ||
                r.kmRodados.toString().contains(busca) ||
                (r.observacao ?? '').toLowerCase().contains(busca) ||
                r.tipo.descricao.toLowerCase().contains(busca);
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
          busca.isEmpty
              ? filtroLancamentos == FiltroLancamentos.somenteCorridas
                  ? 'Nenhuma corrida lançada ainda'
                  : 'Nenhuma receita lançada ainda'
              : 'Nenhum resultado para "$_buscaTexto"',
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
        children: lancamentosFiltrados.map((r) {
          return GestureDetector(
            onDoubleTap: () => _visualizarLancamento(r),
            child: Dismissible(
            key: ValueKey(r.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) => _confirmarExclusao(r),
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
              await context.read<ReceitaProvider>().excluir(r.id);
              if (context.mounted) {
                await context.read<DashboardProvider>().carregar();
              }
            },
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.receitaSoft,
                child: Icon(Icons.arrow_upward_rounded, color: AppColors.receita, size: 18),
              ),
              title: Text(
                Formatters.moeda(r.valorRecebido),
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.tipo.descricao} · ${Formatters.data(r.data)} · ${Formatters.km(r.kmRodados)} · ${Formatters.moeda(r.valorPorKm)}/km',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  if (r.localEmbarque != null || r.localDestino != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${r.localEmbarque ?? '?'} → ${r.localDestino ?? '?'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
