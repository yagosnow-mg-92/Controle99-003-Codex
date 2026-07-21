import '../entities/despesa.dart';

abstract class DespesaRepository {
  Future<List<Despesa>> listar({DateTime? inicio, DateTime? fim});
  Future<Despesa?> buscarPorId(String id);
  Future<void> salvar(Despesa despesa);
  Future<void> excluir(String id);
  Future<List<String>> listarCategorias();
  Future<void> adicionarCategoria(String nome);
}
