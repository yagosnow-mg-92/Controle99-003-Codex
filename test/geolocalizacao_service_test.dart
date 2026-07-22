import 'package:flutter_test/flutter_test.dart';
import 'package:moto_gestor/core/services/geolocalizacao_service.dart';
import 'package:moto_gestor/domain/entities/ponto_rota.dart';

void main() {
  final service = GeolocalizacaoService();

  PontoRota ponto({
    required String id,
    required DateTime timestamp,
    required double longitude,
    double? precisao = 10,
    bool simulado = false,
  }) =>
      PontoRota(
        id: id,
        sessaoId: 'sessao',
        timestamp: timestamp,
        latitude: -16.72,
        longitude: longitude,
        precisaoMetros: precisao,
        localizacaoSimulada: simulado,
      );

  test('inclui pontos urbanos que o filtro antigo havia descartado', () {
    final inicio = DateTime(2026, 7, 22, 18);
    final km = service.distanciaDaTrilhaKm([
      ponto(id: '1', timestamp: inicio, longitude: -43.87),
      // 25 m é uma precisão comum na rua, mas excedia o limite antigo de 20 m.
      ponto(id: '2', timestamp: inicio.add(const Duration(seconds: 10)), longitude: -43.869, precisao: 25),
      ponto(id: '3', timestamp: inicio.add(const Duration(seconds: 20)), longitude: -43.868),
    ]);

    expect(km, closeTo(0.213, 0.01));
  });

  test('descarta ponto simulado e salto de GPS impossível', () {
    final inicio = DateTime(2026, 7, 22, 18);
    final km = service.distanciaDaTrilhaKm([
      ponto(id: '1', timestamp: inicio, longitude: -43.87),
      ponto(id: 'salto', timestamp: inicio.add(const Duration(seconds: 1)), longitude: -43.80),
      ponto(id: 'simulado', timestamp: inicio.add(const Duration(seconds: 2)), longitude: -43.869, simulado: true),
      ponto(id: '2', timestamp: inicio.add(const Duration(seconds: 10)), longitude: -43.869),
    ]);

    expect(km, closeTo(0.107, 0.01));
  });
}
