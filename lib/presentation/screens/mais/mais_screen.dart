import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../configuracoes/configuracoes_screen.dart';
import '../indicadores/indicadores_screen.dart';

/// Menu com as opções secundárias do app. Existe pra não lotar a barra
/// inferior — à medida que novas telas forem entrando (relatórios,
/// exportação de dados, etc.), elas entram aqui, sem precisar mexer na
/// navegação principal.
class MaisScreen extends StatelessWidget {
  const MaisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _ItemMenu(
              icone: Icons.bar_chart_rounded,
              titulo: 'Indicadores',
              subtitulo: 'Filtros, gráficos e métricas detalhadas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IndicadoresScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _ItemMenu(
              icone: Icons.settings_rounded,
              titulo: 'Configurações',
              subtitulo: 'Moto, combustível e metas',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
