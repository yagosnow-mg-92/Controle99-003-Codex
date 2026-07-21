import 'package:flutter/foundation.dart';

import '../../domain/entities/configuracoes.dart';
import '../../domain/repositories/configuracoes_repository.dart';

class ConfiguracoesProvider extends ChangeNotifier {
  final ConfiguracoesRepository _repository;

  ConfiguracoesProvider({required ConfiguracoesRepository repository})
      : _repository = repository;

  bool carregando = true;
  bool salvando = false;
  Configuracoes configuracoes = const Configuracoes();

  Future<void> carregar() async {
    carregando = true;
    notifyListeners();

    configuracoes = await _repository.buscar();

    carregando = false;
    notifyListeners();
  }

  Future<void> salvar(Configuracoes novasConfiguracoes) async {
    salvando = true;
    notifyListeners();

    await _repository.salvar(novasConfiguracoes);
    configuracoes = novasConfiguracoes;

    salvando = false;
    notifyListeners();
  }
}
