import '../entities/configuracoes.dart';

abstract class ConfiguracoesRepository {
  Future<Configuracoes> buscar();
  Future<void> salvar(Configuracoes configuracoes);
}
