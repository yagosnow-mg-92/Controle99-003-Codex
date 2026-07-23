import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantém o app vivo em segundo plano enquanto o motociclista está
/// "online", através de um serviço em primeiro plano do Android (exige
/// uma notificação fixa — é uma regra do próprio sistema operacional,
/// não dá pra rastrear localização em segundo plano sem isso).
///
/// A lógica de GPS em si roda no isolate principal do Flutter, via
/// GeolocalizacaoService — esse serviço só existe para impedir que o
/// Android mate o processo do app enquanto a tela está apagada.
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
  FlutterForegroundTask.setTaskHandler(_CorridaTaskHandler());
}

/// Handler mínimo — não faz nada além de manter o serviço vivo. Toda a
/// lógica real (GPS, banco de dados, máquina de estados) roda no
/// isolate principal do app, que continua ativo graças a esse serviço.
class _CorridaTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
