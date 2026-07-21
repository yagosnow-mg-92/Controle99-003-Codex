import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado de uma solicitação de permissão de localização.
enum ResultadoPermissao { concedida, negada, negadaPermanente, servicoDesligado }

/// Centraliza tudo relacionado a GPS: permissões (incluindo a permissão
/// "sempre permitir" exigida para rastreamento em segundo plano),
/// posição atual, stream contínuo de posições, e conversão de
/// coordenadas em rua/bairro.
class GeolocalizacaoService {
  /// Pede permissão de localização em primeiro plano e, na sequência,
  /// a de segundo plano (obrigatória no Android para o app continuar
  /// rastreando com a tela apagada). Também pede permissão de
  /// notificação (Android 13+), necessária para o serviço em primeiro
  /// plano funcionar.
  Future<ResultadoPermissao> solicitarPermissoes() async {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) return ResultadoPermissao.servicoDesligado;

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied) {
      return ResultadoPermissao.negada;
    }
    if (permissao == LocationPermission.deniedForever) {
      return ResultadoPermissao.negadaPermanente;
    }

    // No Android, a permissão "sempre permitir" (segundo plano) precisa
    // ser pedida separadamente, depois que a de primeiro plano já foi
    // concedida — o sistema não deixa pedir as duas de uma vez.
    final statusSegundoPlano = await Permission.locationAlways.request();
    if (!statusSegundoPlano.isGranted) {
      return statusSegundoPlano.isPermanentlyDenied
          ? ResultadoPermissao.negadaPermanente
          : ResultadoPermissao.negada;
    }

    await Permission.notification.request();

    return ResultadoPermissao.concedida;
  }

  Future<Position?> posicaoAtual() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  /// Stream de posições solicitado a cada segundo e após três metros de
  /// deslocamento, para preservar curvas e gerar uma rota útil no mapa.
  ///
  /// A sobrevivência em segundo plano (o app não ser morto pelo Android
  /// com a tela apagada) é responsabilidade do `ForegroundTaskService`
  /// (flutter_foreground_task), que já é iniciado antes deste stream —
  /// ver `CorridaProvider._retomarRastreamento()`.
  Stream<Position> streamPosicao() {
    return Geolocator.getPositionStream(
      locationSettings: configuracoesRastreamento,
    );
  }

  /// Atualizações curtas preservam curvas e conversões. No Android, também
  /// solicitamos explicitamente o intervalo de um segundo; fora dele, o
  /// sistema usa ao menos o filtro espacial de três metros.
  LocationSettings get configuracoesRastreamento {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );
  }

  /// Converte coordenadas em rua + bairro. Retorna nulos silenciosamente
  /// se a geocodificação falhar (sem internet, sem resultado etc.) — o
  /// app deve continuar funcionando normalmente mesmo sem esse dado.
  Future<({String? rua, String? bairro})> enderecoDe(double latitude, double longitude) async {
    try {
      final resultados = await placemarkFromCoordinates(latitude, longitude);
      if (resultados.isEmpty) return (rua: null, bairro: null);
      final local = resultados.first;
      return (rua: local.street, bairro: local.subLocality);
    } catch (_) {
      return (rua: null, bairro: null);
    }
  }

  /// Distância total (em km) percorrida entre uma lista ordenada de
  /// pontos, somando a distância Haversine entre cada par consecutivo.
  double distanciaTotalKm(List<({double latitude, double longitude})> pontos) {
    if (pontos.length < 2) return 0;
    double totalMetros = 0;
    for (int i = 1; i < pontos.length; i++) {
      totalMetros += Geolocator.distanceBetween(
        pontos[i - 1].latitude,
        pontos[i - 1].longitude,
        pontos[i].latitude,
        pontos[i].longitude,
      );
    }
    return totalMetros / 1000;
  }
}
