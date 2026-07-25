import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';

const _chavePreferenciaTemaEscuro = 'tema_escuro_ativo';

/// Controla qual paleta ([AppColors.definirTema]) está ativa e persiste a
/// escolha do motociclista entre uma abertura do app e outra.
///
/// Importante: trocar o tema aqui não faz o Flutter re-executar
/// automaticamente o `build()` de toda tela que usa `AppColors.algumCampo`
/// — essas são leituras estáticas, não uma escuta reativa. Por isso,
/// `main.dart` troca a `Key` da tela raiz sempre que [temaEscuro] muda,
/// forçando toda a árvore de widgets a ser reconstruída do zero e reler as
/// cores atualizadas. É um gatilho um pouco bruto (perde estado local de
/// telas abertas, como texto sendo digitado), mas é o jeito seguro de
/// aplicar a troca em ~300 pontos do app sem reescrever cada um deles para
/// observar um provider.
class TemaProvider extends ChangeNotifier {
  TemaProvider({required bool temaEscuroInicial}) : _temaEscuro = temaEscuroInicial {
    AppColors.definirTema(escuro: _temaEscuro);
  }

  bool _temaEscuro;
  bool get temaEscuro => _temaEscuro;

  /// Lê a preferência salva (padrão: escuro, mantendo o comportamento
  /// original do app para quem já usava antes dessa opção existir).
  static Future<bool> lerPreferenciaSalva() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_chavePreferenciaTemaEscuro) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> definir({required bool escuro}) async {
    if (escuro == _temaEscuro) return;

    _temaEscuro = escuro;
    AppColors.definirTema(escuro: escuro);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chavePreferenciaTemaEscuro, escuro);
    } catch (_) {
      // Preferência de tema não é crítica — se não conseguir salvar agora,
      // o app continua funcionando normalmente com o tema já trocado.
    }
  }

  Future<void> alternar() => definir(escuro: !_temaEscuro);
}
