import '../entities/receita.dart';

abstract class ReceitaRepository {
  Future<List<Receita>> listar({DateTime? inicio, DateTime? fim});
  Future<Receita?> buscarPorId(String id);
  Future<void> salvar(Receita receita);
  Future<void> excluir(String id);
}
