import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/receita.dart';
import '../../domain/repositories/receita_repository.dart';

/// Estado da tela de Receita: lista de lançamentos recentes e operações
/// de salvar/excluir. Quem quiser reagir a mudanças de receita (ex: o
/// Dashboard) deve chamar seu próprio `carregar()` depois de um `salvar()`
/// bem-sucedido aqui — mantendo cada provider responsável só pelo seu escopo.
class ReceitaProvider extends ChangeNotifier {
  final ReceitaRepository _repository;

  ReceitaProvider({required ReceitaRepository repository}) : _repository = repository;

  bool carregando = true;
  bool salvando = false;
  List<Receita> lancamentos = [];

  Future<void> carregar() async {
    carregando = true;
    notifyListeners();

    lancamentos = await _repository.listar();

    carregando = false;
    notifyListeners();
  }

  Future<void> salvar({
    String? id,
    required DateTime data,
    required double kmRodados,
    required double valorRecebido,
    String? observacao,
    String? localEmbarque,
    String? localDestino,
    TipoReceita tipo = TipoReceita.outro,
  }) async {
    salvando = true;
    notifyListeners();

    // Ao editar, preserva a data de criação original do lançamento —
    // "criado em" não deveria mudar só porque um valor foi corrigido.
    DateTime criadoEm = DateTime.now();
    if (id != null) {
      final existente = lancamentos.where((r) => r.id == id).firstOrNull;
      if (existente != null) criadoEm = existente.criadoEm;
    }

    final receita = Receita(
      id: id ?? '',
      data: data,
      kmRodados: kmRodados,
      valorRecebido: valorRecebido,
      observacao: (observacao == null || observacao.trim().isEmpty) ? null : observacao.trim(),
      criadoEm: criadoEm,
      localEmbarque: (localEmbarque == null || localEmbarque.trim().isEmpty)
          ? null
          : localEmbarque.trim(),
      localDestino: (localDestino == null || localDestino.trim().isEmpty)
          ? null
          : localDestino.trim(),
      tipo: tipo,
    );

    await _repository.salvar(receita);
    await carregar();

    salvando = false;
    notifyListeners();
  }

  Future<void> excluir(String id) async {
    await _repository.excluir(id);
    await carregar();
  }
}
