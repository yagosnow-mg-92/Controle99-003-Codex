import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'corrida/corrida_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'despesas/despesas_screen.dart';
import 'mais/mais_screen.dart';
import 'receita/receita_screen.dart';
import '../providers/dashboard_provider.dart';
import '../providers/receita_provider.dart';

/// Casca de navegação principal. Mantém as áreas do app acessíveis
/// por uma barra inferior, seguindo o padrão Material 3.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Toda vez que um card de corrida é aberto via toque duplo no painel,
  /// esse contador incrementa — usado como parte da `Key` da ReceitaScreen
  /// pra forçar ela a reconstruir do zero e mostrar o novo lançamento,
  /// mesmo que a última coisa aberta tenha sido esse mesmo id de novo.
  int _tiqueAbrirReceita = 0;
  String? _receitaIdParaAbrir;

  Future<void> _irParaReceita({String? receitaId}) async {
    setState(() {
      _index = 2;
      _receitaIdParaAbrir = receitaId;
      _tiqueAbrirReceita++;
    });
    await context.read<ReceitaProvider>().carregar();
  }

  Future<void> _irParaDespesas() async {
    setState(() => _index = 3);
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      DashboardScreen(onVerReceita: (id) => _irParaReceita(receitaId: id), onVerDespesas: _irParaDespesas),
      const CorridaScreen(),
      ReceitaScreen(
        key: ValueKey('receita_tela_$_tiqueAbrirReceita'),
        abrirReceitaId: _receitaIdParaAbrir,
      ),
      const DespesasScreen(),
      const MaisScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: telas),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          setState(() => _index = i);
          // As telas ficam vivas no IndexedStack. Recarrega ao entrar para
          // mostrar também lançamentos automáticos feitos fora delas.
          if (i == 0) await context.read<DashboardProvider>().carregar();
          if (i == 2) await context.read<ReceitaProvider>().carregar();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Painel'),
          NavigationDestination(icon: Icon(Icons.two_wheeler_rounded), label: 'Corrida'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline_rounded), label: 'Receita'),
          NavigationDestination(icon: Icon(Icons.receipt_long_rounded), label: 'Despesas'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Mais'),
        ],
      ),
    );
  }
}
