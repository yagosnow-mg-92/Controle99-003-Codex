import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/ponto_rota.dart';


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

  /// Decide se uma posição recém-chegada deve virar a nova referência do
  /// odômetro em tempo real, e qual passa a ser essa referência.
  ///
  /// Antes vivia dentro do `CorridaProvider`, rodando no isolate principal
  /// (preso à tela). Agora mora aqui porque quem chama isso é o
  /// `TaskHandler` do `flutter_foreground_task`, dentro do isolate do
  /// serviço em primeiro plano — o único que o Android trata com
  /// prioridade de execução consistente mesmo com outro app na tela.
  bool decidirAceite({
    required Position posicao,
    required DateTime agora,
    required PontoRota? referenciaAnterior,
    bool obrigatorio = false,
  }) {
    if (posicao.isMocked || posicao.accuracy > 20) return false;
    if (referenciaAnterior == null || obrigatorio) return true;

    final metros = Geolocator.distanceBetween(
      referenciaAnterior.latitude,
      referenciaAnterior.longitude,
      posicao.latitude,
      posicao.longitude,
    );
    final segundos = agora.difference(referenciaAnterior.timestamp).inMilliseconds / 1000;
    if (segundos <= 0) return false;

    final velocidadeCalculada = metros / segundos;
    // Salto suspeito: rejeita sem mover a referência, para o próximo ponto
    // válido ainda poder ser ligado ao último ponto confiável.
    if (velocidadeCalculada > 55) return false;

    // A diferença entre duas posições isoladas, sozinha, não é confiável:
    // multipath perto de muro/prédio pode "pular" 10-20 m com o veículo
    // parado. Dois sinais corroboram o movimento: a velocidade medida pelo
    // GPS (efeito Doppler, mais resistente a esse ruído) OU o deslocamento
    // superar a soma das margens de erro dos dois pontos — sem exigir
    // precisão perfeita, rara em GPS de celular em movimento.
    final raioIncerteza = (posicao.accuracy + (referenciaAnterior.precisaoMetros ?? 8)) / 2;
    final emMovimento = posicao.speed >= 0.8 ||
        velocidadeCalculada >= math.max(1.4, raioIncerteza * 0.6 / segundos);
    final mudouDirecao =
        _diferencaAngular(posicao.heading, referenciaAnterior.direcaoGraus) >= 30;
    return (metros >= 5 && emMovimento) ||
        (segundos >= 3 && emMovimento) ||
        (metros >= 3 && mudouDirecao && emMovimento);
  }

  double _diferencaAngular(double atual, double? anterior) {
    if (anterior == null || atual < 0 || anterior < 0) return 0;
    final diferenca = (atual - anterior).abs() % 360;
    return diferenca > 180 ? 360 - diferenca : diferenca;
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

  /// Recalcula a distância a partir da trilha bruta gravada.
  ///
  /// O desenho do mapa sempre usa todos os pontos, mas o filtro antigo de
  /// [`PontoRota.aceitoNoCalculo`] era deliberadamente rígido (20 m de
  /// precisão) e podia retirar trechos inteiros da soma. Aqui cada segmento é
  /// validado novamente: toleramos a precisão urbana normal, mas descartamos
  /// localização simulada, leituras muito imprecisas e saltos incompatíveis
  /// com uma moto. Isso mantém o odômetro alinhado ao trajeto exibido sem
  /// somar ruído de GPS parado.
  ///
  /// Antes de somar, também removemos "picos isolados": um ponto que pula
  /// para longe e no ponto seguinte volta pra perto de onde estava — típico
  /// de multipercurso perto de prédio/muro. Isso ataca justamente o padrão
  /// de "ficou parado e o app disse que andou X metros", que a checagem de
  /// velocidade Doppler abaixo, sozinha, pode não pegar se o próprio chip
  /// também relatar uma velocidade espúria durante o mesmo instante ruim.
  double distanciaDaTrilhaKm(List<PontoRota> pontosOriginais) {
    if (pontosOriginais.length < 2) return 0;

    const precisaoMaximaMetros = 25.0;
    const precisaoAltaMetros = 8.0;
    const velocidadeMaximaMetrosPorSegundo = 55.0; // 198 km/h.
    const deslocamentoMinimoMetros = 3.0;
    const velocidadeMinimaDispositivoMps = 0.8;

    final pontos = pontosOriginais.where((p) {
      final precisao = p.precisaoMetros;
      return !p.localizacaoSimulada && (precisao == null || precisao <= precisaoMaximaMetros);
    }).toList();
    if (pontos.length < 2) return 0;

    final filtrados = _removerPicosIsolados(pontos);
    if (filtrados.length < 2) return 0;

    PontoRota? anterior;
    double totalMetros = 0;

    for (final ponto in filtrados) {
      if (anterior == null) {
        anterior = ponto;
        continue;
      }

      final segundos = ponto.timestamp.difference(anterior.timestamp).inMilliseconds / 1000;
      if (segundos <= 0) continue;

      final metros = Geolocator.distanceBetween(
        anterior.latitude,
        anterior.longitude,
        ponto.latitude,
        ponto.longitude,
      );
      final velocidadeCalculada = metros / segundos;

      // Não move a referência quando a leitura é um salto: o próximo ponto
      // válido ainda poderá ser ligado ao último ponto confiável.
      if (velocidadeCalculada > velocidadeMaximaMetrosPorSegundo) continue;

      // A diferença de posição sozinha não distingue "andou 20 m" de
      // "ficou parado e o GPS pulou 20 m por multipath". Dois sinais
      // corroboram o movimento: a velocidade que o próprio chip mediu
      // (efeito Doppler, mais resistente a esse ruído) OU o deslocamento
      // superar a soma das margens de erro (`precisaoMetros`) dos dois
      // pontos — não exigimos precisão perfeita (rara em GPS de celular em
      // movimento), só que a distância percorrida seja maior que o próprio
      // raio de incerteza combinado das duas leituras.
      final confirmadoPeloDispositivo = ponto.velocidadeMetrosPorSegundo != null &&
          ponto.velocidadeMetrosPorSegundo! >= velocidadeMinimaDispositivoMps;
      final raioIncerteza =
          ((anterior.precisaoMetros ?? precisaoAltaMetros) + (ponto.precisaoMetros ?? precisaoAltaMetros)) / 2;
      final deslocamentoAlemDoRuido = metros >= math.max(deslocamentoMinimoMetros, raioIncerteza * 0.6);
      final emMovimento = confirmadoPeloDispositivo || deslocamentoAlemDoRuido;

      if (emMovimento && metros >= deslocamentoMinimoMetros) {
        totalMetros += metros;
      }
      anterior = ponto;
    }

    return totalMetros / 1000;
  }

  /// Remove pontos que "pularam e voltaram" — ida a um lugar distante e
  /// retorno logo em seguida, sem sustentar a posição nova. Compara cada
  /// ponto com seu vizinho anterior aceito e o próximo bruto da lista;
  /// se o caminho direto entre os dois vizinhos é bem mais curto que o
  /// caminho passando pelo ponto do meio, ele é ruído.
  List<PontoRota> _removerPicosIsolados(List<PontoRota> pontos) {
    const distanciaMinimaParaAvaliar = 15.0; // abaixo disso, não vale a pena avaliar como pico.
    const proporcaoMaximaDireto = 0.4;

    final filtrados = <PontoRota>[pontos.first];
    for (int i = 1; i < pontos.length - 1; i++) {
      final anterior = filtrados.last;
      final atual = pontos[i];
      final proximo = pontos[i + 1];

      final distAnteriorAtual = Geolocator.distanceBetween(
        anterior.latitude, anterior.longitude, atual.latitude, atual.longitude,
      );
      final distAtualProximo = Geolocator.distanceBetween(
        atual.latitude, atual.longitude, proximo.latitude, proximo.longitude,
      );
      final distAnteriorProximo = Geolocator.distanceBetween(
        anterior.latitude, anterior.longitude, proximo.latitude, proximo.longitude,
      );

      final ehPicoIsolado = distAnteriorAtual > distanciaMinimaParaAvaliar &&
          distAtualProximo > distanciaMinimaParaAvaliar &&
          distAnteriorProximo < (distAnteriorAtual + distAtualProximo) * proporcaoMaximaDireto;

      if (ehPicoIsolado) continue;
      filtrados.add(atual);
    }
    filtrados.add(pontos.last);
    return filtrados;
  }
}
