import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/ponto_rota.dart';
import '../../../domain/entities/receita.dart';
import '../../../domain/repositories/corrida_repository.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/receita_provider.dart';
import 'mapa_trajeto_screen.dart';

class ReceitaScreen extends StatefulWidget {
  /// Quando informado, a tela já abre com esse lançamento em modo
  /// visualização — usado pelo toque duplo num card de corrida no
  /// carrossel do painel, pra pular direto pra "consultar a corrida".
  final String? abrirReceitaId;
  const ReceitaScreen({super.key, this.abrirReceitaId});

  @override
  State<ReceitaScreen> createState() => _ReceitaScreenState();
}

class _ReceitaScreenState extends State<ReceitaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  final _valorController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _inicioController = TextEditingController();
  final _embarqueController = TextEditingController();
  final _destinoController = TextEditingController();
  final _kmFocusNode = FocusNode();
  final _scrollController = ScrollController();

  DateTime _dataSelecionada = DateTime.now();
  double _valorPorKmPreview = 0;
  String _buscaTexto = '';
  TipoReceita _tipoSelecionado = TipoReceita.outro;

  /// Filtro próprio desta tela — não tem mais relação com o filtro da
  /// tela inicial (esse é só do painel agora). Por padrão, mostra somente
  /// os lançamentos de hoje, de qualquer tipo. `_filtroFim` é exclusivo
  /// (igual ao resto do app): um dia sozinho vira [hoje 00h, amanhã 00h).
  late DateTime _filtroInicio = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late DateTime _filtroFim = _filtroInicio.add(const Duration(days: 1));
  TipoReceita? _filtroTipo;

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ReceitaProvider>();
      await provider.carregar();
      if (!mounted) return;
      final idParaAbrir = widget.abrirReceitaId;
      if (idParaAbrir != null) {
        final receita = provider.lancamentos.where((r) => r.id == idParaAbrir).firstOrNull;
        if (receita != null) _visualizarLancamento(receita);
      }
    });
    _kmController.addListener(_atualizarPreview);
    _valorController.addListener(_atualizarPreview);
  }

  @override
  void dispose() {
    _kmController.dispose();
    _valorController.dispose();
    _observacaoController.dispose();
    _inicioController.dispose();
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
    _inicioController.text = r.localInicio ?? '';
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
    _inicioController.clear();
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
          localInicio: _inicioController.text,
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
    _inicioController.clear();
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
                Text(
                  'Lançamentos recentes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Toque duas vezes num lançamento para ver ou editar',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                _campoBusca(),
                const SizedBox(height: 10),
                _barraFiltro(),
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
                        style: TextStyle(
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
                    child: Padding(
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
              decoration: InputDecoration(
                labelText: 'Tipo de lançamento',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              dropdownColor: AppColors.surfaceElevated,
              style: TextStyle(color: AppColors.textPrimary),
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
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Quilômetros rodados',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                suffixText: 'km',
              ),
              validator: (valor) {
                final numero = double.tryParse((valor ?? '').replaceAll(',', '.'));
                if (numero == null || numero < 0) return 'Informe um valor de km válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _valorController,
              enabled: !_somenteLeitura,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Valor recebido',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixText: 'R\$ ',
              ),
              validator: (valor) {
                final numero = double.tryParse((valor ?? '').replaceAll(',', '.'));
                if (numero == null || numero < 0) return 'Informe um valor recebido válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _observacaoController,
              enabled: !_somenteLeitura,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Observação (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _inicioController,
              enabled: !_somenteLeitura,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Local de início (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.flag_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _embarqueController,
              enabled: !_somenteLeitura,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Local de embarque (opcional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.trip_origin_rounded, color: AppColors.textSecondary, size: 20),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _destinoController,
              enabled: !_somenteLeitura,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
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
          Icon(Icons.timer_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${horaFormatada.format(r.horaInicio!)} até ${horaFormatada.format(r.horaFim!)}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            Formatters.duracao(duracao),
            style: TextStyle(
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
    LatLng? embarque;
    List<PontoRota> pontos;
    if (receita.tipo == TipoReceita.corrida) {
      pontos = await repository.pontosDaCorridaPorReceita(receita.id);
      final corrida = await repository.corridaPorReceita(receita.id);
      if (corrida?.localEmbarqueLat != null && corrida?.localEmbarqueLng != null) {
        embarque = LatLng(corrida!.localEmbarqueLat!, corrida.localEmbarqueLng!);
      }
    } else {
      pontos = await repository.pontosDoDeslocamentoPorReceita(receita.id);
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapaTrajetoScreen(
          pontos: pontos,
          titulo: receita.tipo == TipoReceita.corrida ? 'Trajeto da corrida' : 'Trajeto do deslocamento',
          embarque: embarque,
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
                  side: BorderSide(color: AppColors.lucro),
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
                side: BorderSide(color: AppColors.primary),
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
                side: BorderSide(color: AppColors.border),
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
              Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(
                Formatters.data(_dataSelecionada),
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
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
          Text(
            'Valor por Km',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          Text(
            Formatters.moeda(_valorPorKmPreview),
            style: TextStyle(
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
        title: Text(
          'Excluir lançamento?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Receita de ${Formatters.moeda(receita.valorRecebido)} do dia ${Formatters.data(receita.data)} será excluída permanentemente.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Excluir', style: TextStyle(color: AppColors.despesa)),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }

  Widget _campoBusca() {
    return TextField(
      onChanged: (texto) => setState(() => _buscaTexto = texto),
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Buscar por valor, km ou observação...',
        hintStyle: TextStyle(color: AppColors.textDisabled),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
      ),
    );
  }

  /// Texto curto pro período filtrado: "Hoje", "31/07" (um dia só) ou
  /// "31/07 - 03/08" (intervalo).
  String get _rotuloPeriodoFiltro {
    final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final umDiaSo = _filtroFim.difference(_filtroInicio).inDays == 1;
    if (umDiaSo && _filtroInicio == hoje) return 'Hoje';
    if (umDiaSo) return Formatters.data(_filtroInicio);
    final ultimoDia = _filtroFim.subtract(const Duration(days: 1));
    return '${Formatters.data(_filtroInicio)} - ${Formatters.data(ultimoDia)}';
  }

  Widget _barraFiltro() {
    return InkWell(
      onTap: _abrirFiltro,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Filtrar lançamentos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirFiltro() async {
    DateTime inicioTemp = _filtroInicio;
    DateTime fimTemp = _filtroFim;
    TipoReceita? tipoTemp = _filtroTipo;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final ontem = hoje.subtract(const Duration(days: 1));
            final ehHoje = inicioTemp == hoje && fimTemp == hoje.add(const Duration(days: 1));
            final ehOntem = inicioTemp == ontem && fimTemp == hoje;

            // O SafeArea (não um cálculo manual de padding) é o que garante
            // que o botão "Aplicar filtro" fique acima da barra de
            // navegação do sistema — é o mesmo recurso que já funciona no
            // filtro da tela inicial.
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrar lançamentos',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    Text('Período', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Hoje'),
                          selected: ehHoje,
                          onSelected: (_) {
                            setModalState(() {
                              inicioTemp = hoje;
                              fimTemp = hoje.add(const Duration(days: 1));
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Ontem'),
                          selected: ehOntem,
                          onSelected: (_) {
                            setModalState(() {
                              inicioTemp = ontem;
                              fimTemp = hoje;
                            });
                          },
                        ),
                        ActionChip(
                          avatar: Icon(Icons.date_range_rounded, size: 16, color: AppColors.primary),
                          label: const Text('Escolher intervalo'),
                          onPressed: () async {
                            final intervalo = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(hoje.year - 3),
                              lastDate: hoje,
                              initialDateRange: DateTimeRange(
                                start: inicioTemp,
                                end: fimTemp.subtract(const Duration(days: 1)),
                              ),
                            );
                            if (intervalo != null) {
                              setModalState(() {
                                inicioTemp = DateTime(intervalo.start.year, intervalo.start.month, intervalo.start.day);
                                fimTemp = DateTime(intervalo.end.year, intervalo.end.month, intervalo.end.day)
                                    .add(const Duration(days: 1));
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Builder(builder: (context) {
                        final umDiaSo = fimTemp.difference(inicioTemp).inDays == 1;
                        final ultimoDia = fimTemp.subtract(const Duration(days: 1));
                        final texto = umDiaSo
                            ? Formatters.data(inicioTemp)
                            : '${Formatters.data(inicioTemp)} até ${Formatters.data(ultimoDia)}';
                        return Text(texto, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5));
                      }),
                    ),
                    const SizedBox(height: 22),
                    Text('Tipo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: tipoTemp == null,
                          onSelected: (_) => setModalState(() => tipoTemp = null),
                        ),
                        ChoiceChip(
                          label: const Text('Corrida'),
                          selected: tipoTemp == TipoReceita.corrida,
                          onSelected: (_) => setModalState(() => tipoTemp = TipoReceita.corrida),
                        ),
                        ChoiceChip(
                          label: const Text('Deslocamento livre'),
                          selected: tipoTemp == TipoReceita.deslocamentoLivre,
                          onSelected: (_) => setModalState(() => tipoTemp = TipoReceita.deslocamentoLivre),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filtroInicio = inicioTemp;
                            _filtroFim = fimTemp;
                            _filtroTipo = tipoTemp;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Aplicar filtro'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _listaLancamentos(ReceitaProvider provider) {
    if (provider.carregando) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final lancamentosDoFiltro = provider.lancamentos.where((r) {
      final dentroDoPeriodo = !r.data.isBefore(_filtroInicio) && r.data.isBefore(_filtroFim);
      final tipoBate = _filtroTipo == null || r.tipo == _filtroTipo;
      return dentroDoPeriodo && tipoBate;
    });
    final busca = _buscaTexto.trim().toLowerCase();
    final lancamentosFiltrados = busca.isEmpty
        ? lancamentosDoFiltro.toList()
        : lancamentosDoFiltro.where((r) {
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
              ? 'Nenhum lançamento em "$_rotuloPeriodoFiltro"'
              : 'Nenhum resultado para "$_buscaTexto" em "$_rotuloPeriodoFiltro"',
          textAlign: TextAlign.center,
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
              child: Icon(Icons.delete_outline_rounded, color: AppColors.despesa),
            ),
            onDismissed: (_) async {
              await context.read<ReceitaProvider>().excluir(r.id);
              if (context.mounted) {
                await context.read<DashboardProvider>().carregar();
              }
            },
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.receitaSoft,
                child: Icon(Icons.arrow_upward_rounded, color: AppColors.receita, size: 18),
              ),
              title: Text(
                Formatters.moeda(r.valorRecebido),
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r.tipo.descricao} · ${Formatters.data(r.data)} · ${Formatters.km(r.kmRodados)} · ${Formatters.moeda(r.valorPorKm)}/km',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  if (r.localInicio != null || r.localEmbarque != null || r.localDestino != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${r.localEmbarque ?? r.localInicio ?? '?'} → ${r.localDestino ?? '?'}',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
