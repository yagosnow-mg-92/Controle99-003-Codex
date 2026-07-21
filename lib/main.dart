import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/services/foreground_task_service.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/configuracoes_repository_impl.dart';
import 'data/repositories/corrida_repository_impl.dart';
import 'data/repositories/despesa_repository_impl.dart';
import 'data/repositories/receita_repository_impl.dart';
import 'domain/repositories/configuracoes_repository.dart';
import 'domain/repositories/corrida_repository.dart';
import 'domain/repositories/despesa_repository.dart';
import 'domain/repositories/receita_repository.dart';
import 'presentation/providers/configuracoes_provider.dart';
import 'presentation/providers/corrida_provider.dart';
import 'presentation/providers/dashboard_provider.dart';
import 'presentation/providers/despesa_provider.dart';
import 'presentation/providers/indicadores_provider.dart';
import 'presentation/providers/receita_provider.dart';
import 'presentation/screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  ForegroundTaskService.inicializar();
  runApp(const MotoGestorApp());
}

/// Ponto único de injeção de dependências manual (sem framework externo,
/// mantendo o projeto simples de entender e evoluir). Repositórios são
/// expostos pela interface de domínio, nunca pela implementação concreta,
/// permitindo trocar a fonte de dados (ex.: sincronização em nuvem) no futuro.
class MotoGestorApp extends StatelessWidget {
  const MotoGestorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ReceitaRepository>(create: (_) => ReceitaRepositoryImpl()),
        Provider<DespesaRepository>(create: (_) => DespesaRepositoryImpl()),
        Provider<ConfiguracoesRepository>(create: (_) => ConfiguracoesRepositoryImpl()),
        Provider<CorridaRepository>(create: (_) => CorridaRepositoryImpl()),
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
            receitaRepository: context.read<ReceitaRepository>(),
            despesaRepository: context.read<DespesaRepository>(),
          ),
        ),
        ChangeNotifierProvider<ReceitaProvider>(
          create: (context) => ReceitaProvider(
            repository: context.read<ReceitaRepository>(),
          ),
        ),
        ChangeNotifierProvider<DespesaProvider>(
          create: (context) => DespesaProvider(
            repository: context.read<DespesaRepository>(),
          ),
        ),
        ChangeNotifierProvider<IndicadoresProvider>(
          create: (context) => IndicadoresProvider(
            receitaRepository: context.read<ReceitaRepository>(),
            despesaRepository: context.read<DespesaRepository>(),
          ),
        ),
        ChangeNotifierProvider<ConfiguracoesProvider>(
          create: (context) => ConfiguracoesProvider(
            repository: context.read<ConfiguracoesRepository>(),
          ),
        ),
        ChangeNotifierProvider<CorridaProvider>(
          create: (context) => CorridaProvider(
            repository: context.read<CorridaRepository>(),
            receitaRepository: context.read<ReceitaRepository>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Moto Gestor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeShell(),
      ),
    );
  }
}
