import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/repositories/corrida_repository_impl.dart';
import '../../domain/entities/ponto_rota.dart';
import 'geolocalizacao_service.dart';

const _chaveSessaoId = 'corrida_sessaoId';
const _chaveCorridaId = 'corrida_corridaId';

/// Mantém o app vivo em segundo plano enquanto o motociclista está
/// "online", através de um serviço em primeiro plano do Android (exige
/// uma notificação fixa — é uma regra do próprio sistema operacional,
/// não dá pra rastrear localização em segundo plano sem isso).
///
/// A captura do GPS roda dentro do isolate deste serviço (`_CorridaTaskHandler`),
/// não mais no isolate principal do app. Isso importa porque o isolate
/// principal fica preso ao ciclo de vida da tela: quando outro app (ex.: o
/// app da 99) assume o primeiro plano de verdade, o Android pode manter o
/// processo vivo (graças à notificação fixa) mas degradar a prioridade/
/// precisão do que é entregue a esse isolate. O isolate do serviço em
/// primeiro plano é o único que o Android trata de forma consistente
/// independente de qual app está visível.
class ForegroundTaskService {
  static void inicializar() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'moto_gestor_corrida',
        channelName: 'Moto Gestor - Corrida em andamento',
        channelDescription: 'Rastreando sua localização enquanto você está online.',
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  static Future<void> iniciar() async {
    // Não precisa de permissão adicional no Android. Repetimos a chamada
    // quando o app é retomado porque o sistema pode liberar o wake lock.
    await WakelockPlus.enable();

    try {
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
        notificationTitle: 'Moto Gestor',
        notificationText: 'Você está online — rastreando localização.',
        callback: _iniciarCallback,
      );
    } catch (_) {
      // Se o serviço não puder iniciar, não deixamos a tela presa ligada.
      await WakelockPlus.disable();
      rethrow;
    }
  }

  /// Informa ao isolate do serviço qual sessão/corrida está ativa agora,
  /// para que os pontos de GPS gravados por ele já saiam vinculados ao
  /// lugar certo. Persistido via `saveData` (sobrevive a uma eventual
  /// reinicialização do isolate do serviço) e também enviado ao vivo via
  /// `sendDataToTask`, para efeito imediato enquanto o serviço já está de pé.
  static Future<void> atualizarSessao({
    required String? sessaoId,
    required String? corridaId,
  }) async {
    await FlutterForegroundTask.saveData(key: _chaveSessaoId, value: sessaoId ?? '');
    await FlutterForegroundTask.saveData(key: _chaveCorridaId, value: corridaId ?? '');
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({
        'sessaoId': sessaoId,
        'corridaId': corridaId,
      });
    }
  }

  static Future<void> atualizarNotificacao(String texto) async {
    if (!await FlutterForegroundTask.isRunningService) return;
    FlutterForegroundTask.updateService(
      notificationTitle: 'Moto Gestor',
      notificationText: texto,
    );
  }

  static Future<void> parar() async {
    try {
      await FlutterForegroundTask.stopService();
    } finally {
      await FlutterForegroundTask.saveData(key: _chaveSessaoId, value: '');
      await FlutterForegroundTask.saveData(key: _chaveCorridaId, value: '');
      // Fora do modo online a tela volta a obedecer o tempo configurado pelo
      // motociclista, evitando gasto de bateria desnecessário.
      await WakelockPlus.disable();
    }
  }
}

/// Ponto de entrada do isolate do serviço em primeiro plano. Precisa ser
/// uma função top-level (ou estática) anotada com `@pragma('vm:entry-point')`
/// para o Android conseguir chamá-la mesmo com o app minimizado.
@pragma('vm:entry-point')
void _iniciarCallback() {
  // Necessário para que plugins com canal de plataforma (geolocator,
  // sqflite) funcionem dentro deste isolate, que não é o isolate principal.
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(_CorridaTaskHandler());
}

/// Handler que roda dentro do serviço em primeiro plano: escuta o GPS e
/// grava cada ponto direto no banco, sem depender do isolate principal
/// estar vivo, visível ou em primeiro plano.
class _CorridaTaskHandler extends TaskHandler {
  final _geo = GeolocalizacaoService();
  final _repository = CorridaRepositoryImpl();
  final _uuid = const Uuid();

  StreamSubscription<Position>? _posicaoSubscription;
  String? _sessaoId;
  String? _corridaId;
  PontoRota? _ultimoPontoAceito;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Recupera a sessão/corrida ativa persistida pelo isolate principal —
    // cobre tanto o início normal (ficarOnline já salvou antes de iniciar
    // o serviço) quanto uma eventual reinicialização do serviço pelo Android.
    _sessaoId = await FlutterForegroundTask.getData<String>(key: _chaveSessaoId);
    _corridaId = await FlutterForegroundTask.getData<String>(key: _chaveCorridaId);
    if (_sessaoId?.isEmpty ?? true) _sessaoId = null;
    if (_corridaId?.isEmpty ?? true) _corridaId = null;

    _posicaoSubscription = _geo.streamPosicao().listen(_aoReceberPosicao);
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    if (data.containsKey('sessaoId')) _sessaoId = data['sessaoId'] as String?;
    if (data.containsKey('corridaId')) {
      _corridaId = data['corridaId'] as String?;
      // Troca de trecho (ex.: começou uma corrida nova): a referência de
      // velocidade/direção do trecho anterior não deve influenciar o novo.
      _ultimoPontoAceito = null;
    }
  }

  Future<void> _aoReceberPosicao(Position posicao) async {
    final sessaoId = _sessaoId;
    if (sessaoId == null) return;

    final agora = DateTime.now();
    final aceito = _geo.decidirAceite(
      posicao: posicao,
      agora: agora,
      referenciaAnterior: _ultimoPontoAceito,
    );

    final ponto = PontoRota(
      id: _uuid.v4(),
      sessaoId: sessaoId,
      corridaId: _corridaId,
      timestamp: agora,
      latitude: posicao.latitude,
      longitude: posicao.longitude,
      precisaoMetros: posicao.accuracy,
      velocidadeMetrosPorSegundo: posicao.speed,
      direcaoGraus: posicao.heading,
      altitudeMetros: posicao.altitude,
      precisaoVelocidadeMetrosPorSegundo: posicao.speedAccuracy,
      localizacaoSimulada: posicao.isMocked,
      aceitoNoCalculo: aceito,
    );

    try {
      await _repository.registrarPontoRota(ponto);
    } catch (_) {
      // Nunca deixa uma falha pontual de gravação derrubar o stream de GPS.
      return;
    }
    if (aceito) _ultimoPontoAceito = ponto;
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _posicaoSubscription?.cancel();
  }
}
