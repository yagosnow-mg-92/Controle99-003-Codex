import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/ponto_rota.dart';

/// Mostra o trajeto gravado por GPS de uma corrida ou deslocamento livre:
/// linha conectando os pontos, marcador verde no início e vermelho no fim.
class MapaTrajetoScreen extends StatelessWidget {
  final List<PontoRota> pontos;
  final String titulo;

  const MapaTrajetoScreen({super.key, required this.pontos, required this.titulo});

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(titulo)),
        body: const Center(
          child: Text(
            'Nenhum ponto de GPS foi gravado para esse lançamento.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final coordenadas = pontos.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final inicio = coordenadas.first;
    final fim = coordenadas.last;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.coordinates(
            coordinates: coordenadas,
            padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.motogestor.app.moto_gestor',
          ),
          PolylineLayer(
            polylines: [
              Polyline(points: coordenadas, strokeWidth: 4, color: AppColors.primary),
            ],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: inicio,
                width: 36,
                height: 36,
                child: const _PinoMapa(cor: AppColors.receita, icone: Icons.trip_origin_rounded),
              ),
              if (fim != inicio)
                Marker(
                  point: fim,
                  width: 36,
                  height: 36,
                  child: const _PinoMapa(cor: AppColors.despesa, icone: Icons.location_on_rounded),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinoMapa extends StatelessWidget {
  final Color cor;
  final IconData icone;
  const _PinoMapa({required this.cor, required this.icone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
      child: Icon(icone, color: Colors.white, size: 18),
    );
  }
}
