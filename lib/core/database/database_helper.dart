import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Ponto único de acesso ao banco SQLite local.
/// A arquitetura permite, futuramente, trocar essa camada por uma
/// implementação com sincronização em nuvem sem afetar o domínio,
/// pois os repositórios dependem apenas das interfaces em `domain/repositories`.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'moto_gestor.db');

    return openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE receitas (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        km_rodados REAL NOT NULL,
        valor_recebido REAL NOT NULL,
        valor_por_km REAL NOT NULL,
        observacao TEXT,
        criado_em TEXT NOT NULL,
        local_embarque TEXT,
        local_destino TEXT,
        tipo TEXT NOT NULL DEFAULT 'outro',
        hora_inicio TEXT,
        hora_fim TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE despesas (
        id TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        categoria TEXT NOT NULL,
        valor REAL NOT NULL,
        observacao TEXT,
        criado_em TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias_despesa (
        nome TEXT PRIMARY KEY
      )
    ''');

    await db.execute('''
      CREATE TABLE configuracoes (
        chave TEXT PRIMARY KEY,
        valor TEXT NOT NULL
      )
    ''');

    // Categorias padrão sugeridas (o usuário pode adicionar outras livremente)
    const categoriasPadrao = [
      'Gasolina', 'Óleo', 'Filtro de óleo', 'Pneu', 'Câmara de ar',
      'Manutenção', 'Lavagem', 'Freios', 'Relação', 'Capacete',
      'Equipamentos', 'Alimentação', 'Estacionamento', 'Outras despesas',
    ];
    for (final categoria in categoriasPadrao) {
      await db.insert('categorias_despesa', {'nome': categoria});
    }

    await _criarTabelasCorrida(db);
  }

  /// Roda quando um usuário que já tinha o app instalado (versão 1 do
  /// banco) recebe uma atualização. Só CRIA as tabelas novas — nunca
  /// altera ou apaga as tabelas antigas, preservando 100% dos dados que
  /// a pessoa já tinha lançado.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // _criarTabelasCorrida já cria `corridas` com as colunas de
      // embarque/destino incluídas (são a versão atual do schema).
      await _criarTabelasCorrida(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE receitas ADD COLUMN local_embarque TEXT');
      await db.execute('ALTER TABLE receitas ADD COLUMN local_destino TEXT');

      // Só faz ALTER em `corridas` se ela já existia ANTES desta
      // migração (veio da v2). Se acabou de ser criada agora mesmo
      // (alguém pulando direto de v1 para v3), ela já nasce com as
      // colunas — tentar adicionar de novo daria erro de "coluna duplicada".
      if (oldVersion >= 2) {
        await db.execute('ALTER TABLE corridas ADD COLUMN local_embarque TEXT');
        await db.execute('ALTER TABLE corridas ADD COLUMN local_destino TEXT');
      }
    }
    if (oldVersion < 4) {
      // Lançamentos existentes são manuais/legados, portanto entram como
      // "Outro". Os novos registros de GPS informam Corrida ou Deslocamento.
      await db.execute("ALTER TABLE receitas ADD COLUMN tipo TEXT NOT NULL DEFAULT 'outro'");
      // Para quem vem da v1, a tabela acabou de ser criada acima com a
      // coluna atual. Nas versões 2 e 3 ela já existia e precisa do ALTER.
      if (oldVersion >= 2) {
        await db.execute(
          'ALTER TABLE pontos_rota ADD COLUMN lancado_como_deslocamento INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 5) {
      // Mantemos todos os dados brutos para mapa/auditoria, mas guardamos
      // também quais pontos passaram pelo filtro de quilometragem.
      // Quem vem da v1 recebeu a tabela atual em `_criarTabelasCorrida`.
      if (oldVersion >= 2) {
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN precisao_metros REAL');
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN velocidade_mps REAL');
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN direcao_graus REAL');
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN altitude_metros REAL');
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN precisao_velocidade_mps REAL');
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN localizacao_simulada INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE pontos_rota ADD COLUMN aceito_calculo INTEGER NOT NULL DEFAULT 1');
      }
    }
    if (oldVersion < 6 && oldVersion >= 2) {
      await db.execute('ALTER TABLE pontos_rota ADD COLUMN deslocamento_id TEXT');
      await _criarTabelaDeslocamentosLivres(db);
    }
    if (oldVersion < 7) {
      // Hora de início/fim de cada lançamento gerado via GPS (corrida ou
      // deslocamento livre), usadas em relatórios futuros de tempo parado
      // e no botão de mapa. Lançamentos manuais ficam com esses campos
      // nulos — não têm um trajeto de GPS associado.
      await db.execute('ALTER TABLE receitas ADD COLUMN hora_inicio TEXT');
      await db.execute('ALTER TABLE receitas ADD COLUMN hora_fim TEXT');
    }
  }

  Future<void> _criarTabelasCorrida(Database db) async {
    // Uma "sessão de trabalho" é o período entre "Ficar online" e
    // "Ficar offline". status: offline | online | corrida_iniciada | com_passageiro
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessoes_trabalho (
        id TEXT PRIMARY KEY,
        inicio TEXT NOT NULL,
        fim TEXT,
        status TEXT NOT NULL
      )
    ''');

    // Registro de cada clique importante (ficou online, iniciou corrida,
    // cancelou, pegou passageiro, finalizou, ficou offline), com
    // localização e endereço no momento do clique.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS eventos_sessao (
        id TEXT PRIMARY KEY,
        sessao_id TEXT NOT NULL,
        tipo TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        rua TEXT,
        bairro TEXT
      )
    ''');

    // Uma corrida individual dentro de uma sessão.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS corridas (
        id TEXT PRIMARY KEY,
        sessao_id TEXT NOT NULL,
        hora_inicio TEXT NOT NULL,
        hora_fim TEXT,
        valor REAL NOT NULL,
        cancelada INTEGER NOT NULL DEFAULT 0,
        km_percorrido REAL NOT NULL DEFAULT 0,
        receita_id TEXT,
        local_embarque TEXT,
        local_destino TEXT
      )
    ''');

    // Trajeto gravado por GPS. corrida_id fica nulo enquanto o motociclista
    // está apenas "online" (procurando corrida), e preenchido quando uma
    // corrida está em andamento — permite reconstruir tanto o trajeto de
    // busca quanto o da corrida em si.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pontos_rota (
        id TEXT PRIMARY KEY,
        sessao_id TEXT NOT NULL,
        corrida_id TEXT,
        timestamp TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        lancado_como_deslocamento INTEGER NOT NULL DEFAULT 0,
        precisao_metros REAL,
        velocidade_mps REAL,
        direcao_graus REAL,
        altitude_metros REAL,
        precisao_velocidade_mps REAL,
        localizacao_simulada INTEGER NOT NULL DEFAULT 0,
        aceito_calculo INTEGER NOT NULL DEFAULT 1,
        deslocamento_id TEXT
      )
    ''');

    await _criarTabelaDeslocamentosLivres(db);
  }

  /// Cada trecho livre recebe identidade própria para que o lançamento de
  /// receita possa abrir exatamente a rota correspondente em um mapa futuro.
  Future<void> _criarTabelaDeslocamentosLivres(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deslocamentos_livres (
        id TEXT PRIMARY KEY,
        sessao_id TEXT NOT NULL,
        inicio TEXT NOT NULL,
        fim TEXT NOT NULL,
        km_percorrido REAL NOT NULL,
        receita_id TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
