import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/foreground_task_service.dart';
import '../../core/services/geolocalizacao_service.dart';
import '../../domain/entities/corrida.dart';
import '../../domain/entities/evento_sessao.dart';
import '../../domain/entities/ponto_rota.dart';
import '../../domain/entities/receita.dart';
import '../../domain/entities/sessao_trabalho.dart';
import '../../domain/entities/status_sessao.dart';
import '../../domain/repositories/corrida_repository.dart';
import '../../domain/repositories/receita_repository.dart';

class CorridaProvider extends ChangeNotifier {
  final CorridaRepository _repository;
  final ReceitaRepository _receitaRepository;
  final GeolocalizacaoService _geo;
  final _uuid = const Uuid();

  CorridaProvider({
    required CorridaRepository repository,
    required ReceitaRepository receitaRepository,
    GeolocalizacaoService? geolocalizacaoService,
  })  : _repository = repository,
        _receitaRepository = receitaRepository,
        _geo = geolocalizacaoService ?? GeolocalizacaoService();

  bool carregando = true;
  bool processando = false;
  String? erro;

  SessaoTrabalho? sessaoAtual;
  Corrida? corridaAtual;
  StatusSessao get status => sessaoAtual?.status ?? StatusSessao.offline;

  Duration tempoDecorrido = Duration.zero;
  String? enderecoAtual;

  Timer? _timer;
  StreamSubscription<Position>? _posicaoSubscription;
  Position? _ultimaPosicaoConhecida;
  PontoRota? _ultimoPontoAceito;

  /// Chamado uma vez quando a tela Corrida é aberta pela primeira vez.
  /// Restaura o estado caso o motociclista tenha ficado online e o app
  /// tenha sido fechado (pela própria pessoa ou pelo sistema).
  Future<void> inicializar() async {
    carregando = true;
    notifyListeners();

    final sessaoAberta = await _repository.sessaoAberta();
    if (sessaoAberta != null) {
      sessaoAtual = sessaoAberta;
      if (sessaoAberta.status == StatusSessao.corridaIniciada ||
          sessaoAberta.status == StatusSessao.comPassageiro) {
        corridaAtual = await _repository.corridaAberta(sessaoAberta.id);
      }
      await _retomarRastreamento();
    }

    carregando = false;
    notifyListeners();
  }

  Future<void> _retomarRastreamento() async {
    await ForegroundTaskService.iniciar();
    _iniciarTimer();
    _iniciarStreamPosicao();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sessaoAtual != null) {
        tempoDecorrido = sessaoAtual!.duracao;
        notifyListeners();
      }
    });
  }

  void _iniciarStreamPosicao() {
    _posicaoSubscription?.cancel();
    _posicaoSubscription = _geo.streamPosicao().listen((posicao) async {
      _ultimaPosicaoConhecida = posicao;
      await _registrarPosicao(posicao);
    });
  }

  /// Salva todos os pontos para o mapa, mas marca apenas os confiáveis para a
  /// distância financeira. Assim, sinal ruim não infla o odômetro e continua
  /// disponível para diagnóstico futuro.
  Future<void> _registrarPosicao(Position posicao, {bool obrigatorio = false}) async {
    final sessao = sessaoAtual;
    if (sessao == null) return;

    final agora = DateTime.now();
    final aceito = _deveAceitarNoCalculo(posicao, agora, obrigatorio: obrigatorio);
    final ponto = PontoRota(
      id: _uuid.v4(),
      sessaoId: sessao.id,
      corridaId: corridaAtual?.id,
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
    await _repository.registrarPontoRota(ponto);
    if (aceito) _ultimoPontoAceito = ponto;
  }

  bool _deveAceitarNoCalculo(
    Position posicao,
    DateTime agora, {
    required bool obrigatorio,
  }) {
    if (posicao.isMocked || posicao.accuracy > 20) return false;

    final anterior = _ultimoPontoAceito;
    if (anterior == null || obrigatorio) return true;

    final metros = Geolocator.distanceBetween(
      anterior.latitude,
      anterior.longitude,
      posicao.latitude,
      posicao.longitude,
    );
    final segundos = agora.difference(anterior.timestamp).inMilliseconds / 1000;
    if (segundos <= 0) return false;

    final velocidadeCalculada = metros / segundos;
    if (velocidadeCalculada > 55) return false;

    final emMovimento = posicao.speed >= 1 || velocidadeCalculada >= 1.4;
    final mudouDirecao = _diferencaAngular(posicao.heading, anterior.direcaoGraus) >= 30;
    return (metros >= 5 && emMovimento) ||
        (segundos >= 3 && emMovimento) ||
        (metros >= 3 && mudouDirecao && emMovimento);
  }

  double _diferencaAngular(double atual, double? anterior) {
    if (anterior == null || atual < 0 || anterior < 0) return 0;
    final diferenca = (atual - anterior).abs() % 360;
    return diferenca > 180 ? 360 - diferenca : diferenca;
  }

  Future<void> _registrarPosicaoAtualObrigatoria() async {
    final posicao = await _geo.posicaoAtual();
    if (posicao != null) {
      _ultimaPosicaoConhecida = posicao;
      await _registrarPosicao(posicao, obrigatorio: true);
    }
  }

  Future<({double? lat, double? lng, String? rua, String? bairro})> _capturarLocalizacao() async {
    final posicao = _ultimaPosicaoConhecida ?? await _geo.posicaoAtual();
    if (posicao == null) return (lat: null, lng: null, rua: null, bairro: null);

    final endereco = await _geo.enderecoDe(posicao.latitude, posicao.longitude);
    return (lat: posicao.latitude, lng: posicao.longitude, rua: endereco.rua, bairro: endereco.bairro);
  }

  Future<void> _registrarEvento(String sessaoId, TipoEvento tipo) async {
    final local = await _capturarLocalizacao();
    enderecoAtual = [local.rua, local.bairro].where((s) => s != null && s.isNotEmpty).join(', ');

    await _repository.registrarEvento(EventoSessao(
      id: _uuid.v4(),
      sessaoId: sessaoId,
      tipo: tipo,
      timestamp: DateTime.now(),
      latitude: local.lat,
      longitude: local.lng,
      rua: local.rua,
      bairro: local.bairro,
    ));
  }

  /// Etapa 1: Ficar online. Pede permissões, cria a sessão, inicia o
  /// serviço em primeiro plano e começa a gravar localização.
  Future<bool> ficarOnline() async {
    processando = true;
    erro = null;
    notifyListeners();

    final resultado = await _geo.solicitarPermissoes();
    if (resultado != ResultadoPermissao.concedida) {
      erro = switch (resultado) {
        ResultadoPermissao.servicoDesligado => 'Ative o GPS do celular para continuar.',
        ResultadoPermissao.negadaPermanente =>
          'Permissão de localização negada permanentemente. Habilite manualmente '
              'nas configurações do app (Localização → Permitir o tempo todo).',
        _ => 'É necessário permitir o acesso à localização para ficar online.',
      };
      processando = false;
      notifyListeners();
      return false;
    }

    final sessao = await _repository.criarSessao(DateTime.now());
    sessaoAtual = sessao;
    _ultimoPontoAceito = null;
    tempoDecorrido = Duration.zero;

    await _registrarEvento(sessao.id, TipoEvento.ficouOnline);
    await _retomarRastreamento();
    await _registrarPosicaoAtualObrigatoria();

    processando = false;
    notifyListeners();
    return true;
  }

  /// Etapa 2: Iniciar corrida — pede o valor e começa a contabilizar a
  /// corrida em si (a rota gravada a partir daqui já fica vinculada a ela).
  Future<void> iniciarCorrida(double valor) async {
    if (sessaoAtual == null) return;
    processando = true;
    notifyListeners();

    // Tudo que foi percorrido enquanto estava online, antes de aceitar esta
    // corrida, é um deslocamento sem remuneração e precisa ficar separado da
    // receita da corrida.
    await _lancarDeslocamentoLivreSeNecessario();
    await _registrarEvento(sessaoAtual!.id, TipoEvento.iniciouCorrida);
    // Guarda como fallback de "local de embarque": se a corrida for
    // cancelada antes de pegar o passageiro, é o melhor endereço que
    // temos. Se o passageiro for pego de fato, `pegarPassageiro()`
    // substitui por um endereço mais preciso.
    final enderecoInicio = enderecoAtual;

    final corrida = await _repository.criarCorrida(
      sessaoId: sessaoAtual!.id,
      horaInicio: DateTime.now(),
      valor: valor,
    );
    corridaAtual = corrida.copyWith(localEmbarque: enderecoInicio);
    if (enderecoInicio != null) {
      await _repository.atualizarLocalEmbarque(corrida.id, enderecoInicio);
    }
    await _registrarPosicaoAtualObrigatoria();

    await _repository.atualizarStatusSessao(sessaoAtual!.id, StatusSessao.corridaIniciada);
    sessaoAtual = sessaoAtual!.copyWith(status: StatusSessao.corridaIniciada);

    await ForegroundTaskService.atualizarNotificacao('Corrida em andamento.');

    processando = false;
    notifyListeners();
  }

  /// Cancelar a corrida — pede o valor da taxa de deslocamento e volta
  /// para "online". A taxa também é lançada como Receita (é dinheiro
  /// recebido de verdade, só que menor que uma corrida completa).
  Future<void> cancelarCorrida(double valorTaxa) async {
    if (sessaoAtual == null || corridaAtual == null) return;
    processando = true;
    notifyListeners();

    await _registrarPosicaoAtualObrigatoria();
    await _registrarEvento(sessaoAtual!.id, TipoEvento.cancelouCorrida);
    final enderecoFim = enderecoAtual;

    final km = await _calcularKmDaCorrida(corridaAtual!.id);
    await _repository.atualizarValorCorrida(corridaAtual!.id, valorTaxa, cancelada: true);
    final horaFimCorrida = DateTime.now();
    await _repository.finalizarCorrida(
      corridaAtual!.id,
      horaFimCorrida,
      km,
      localDestino: enderecoFim,
    );

    final receitaId = _uuid.v4();
    final receita = Receita(
      id: receitaId,
      data: DateTime.now(),
      kmRodados: km,
      valorRecebido: valorTaxa,
      observacao: 'Taxa de cancelamento — lançado automaticamente pela função Corrida',
      criadoEm: DateTime.now(),
      localEmbarque: corridaAtual!.localEmbarque,
      localDestino: enderecoFim,
      tipo: TipoReceita.corrida,
      horaInicio: corridaAtual!.horaInicio,
      horaFim: horaFimCorrida,
    );
    await _receitaRepository.salvar(receita);
    await _repository.vincularReceita(corridaAtual!.id, receitaId);

    corridaAtual = null;
    await _repository.atualizarStatusSessao(sessaoAtual!.id, StatusSessao.online);
    sessaoAtual = sessaoAtual!.copyWith(status: StatusSessao.online);

    await ForegroundTaskService.atualizarNotificacao('Você está online — procurando corrida.');

    processando = false;
    notifyListeners();
  }

  /// Peguei o passageiro — a corrida continua, só muda o status visual.
  /// Esse é o endereço que vira "local de embarque" no lançamento final.
  Future<void> pegarPassageiro() async {
    if (sessaoAtual == null || corridaAtual == null) return;
    processando = true;
    notifyListeners();

    await _registrarEvento(sessaoAtual!.id, TipoEvento.pegouPassageiro);
    final enderecoEmbarque = enderecoAtual;

    if (enderecoEmbarque != null) {
      await _repository.atualizarLocalEmbarque(corridaAtual!.id, enderecoEmbarque);
      corridaAtual = corridaAtual!.copyWith(localEmbarque: enderecoEmbarque);
    }

    await _repository.atualizarStatusSessao(sessaoAtual!.id, StatusSessao.comPassageiro);
    sessaoAtual = sessaoAtual!.copyWith(status: StatusSessao.comPassageiro);

    await ForegroundTaskService.atualizarNotificacao('Corrida com passageiro a bordo.');

    processando = false;
    notifyListeners();
  }

  /// Finalizar corrida — calcula o Km rodado a partir da rota gravada
  /// pelo GPS e já lança automaticamente como Receita.
  Future<void> finalizarCorrida() async {
    if (sessaoAtual == null || corridaAtual == null) return;
    processando = true;
    notifyListeners();

    await _registrarPosicaoAtualObrigatoria();
    await _registrarEvento(sessaoAtual!.id, TipoEvento.finalizouCorrida);
    final enderecoFim = enderecoAtual;

    final km = await _calcularKmDaCorrida(corridaAtual!.id);
    final horaFimCorrida = DateTime.now();
    await _repository.finalizarCorrida(
      corridaAtual!.id,
      horaFimCorrida,
      km,
      localDestino: enderecoFim,
    );

    final receitaId = _uuid.v4();
    final receita = Receita(
      id: receitaId,
      data: DateTime.now(),
      kmRodados: km,
      valorRecebido: corridaAtual!.valor,
      observacao: 'Lançado automaticamente pela função Corrida',
      criadoEm: DateTime.now(),
      localEmbarque: corridaAtual!.localEmbarque,
      localDestino: enderecoFim,
      tipo: TipoReceita.corrida,
      horaInicio: corridaAtual!.horaInicio,
      horaFim: horaFimCorrida,
    );
    await _receitaRepository.salvar(receita);
    await _repository.vincularReceita(corridaAtual!.id, receitaId);

    corridaAtual = null;
    await _repository.atualizarStatusSessao(sessaoAtual!.id, StatusSessao.online);
    sessaoAtual = sessaoAtual!.copyWith(status: StatusSessao.online);

    await ForegroundTaskService.atualizarNotificacao('Você está online — procurando corrida.');

    processando = false;
    notifyListeners();
  }

  /// Ficar offline — encerra a sessão e para o rastreamento.
  Future<void> ficarOffline() async {
    if (sessaoAtual == null) return;
    processando = true;
    notifyListeners();

    await _registrarPosicaoAtualObrigatoria();
    // Se a sessão terminou sem corrida (ou entre duas corridas), registra o
    // que foi rodado procurando trabalho como um lançamento de valor zero.
    if (status == StatusSessao.online) {
      await _lancarDeslocamentoLivreSeNecessario();
    }
    await _registrarEvento(sessaoAtual!.id, TipoEvento.ficouOffline);
    await _repository.encerrarSessao(sessaoAtual!.id, DateTime.now());

    _timer?.cancel();
    await _posicaoSubscription?.cancel();
    await ForegroundTaskService.parar();

    sessaoAtual = null;
    corridaAtual = null;
    _ultimoPontoAceito = null;
    tempoDecorrido = Duration.zero;

    processando = false;
    notifyListeners();
  }

  Future<double> _calcularKmDaCorrida(String corridaId) async {
    final pontos = await _repository.pontosDaCorrida(corridaId);
    return _arredondarKmGps(_geo.distanciaTotalKm(
      pontos.map((p) => (latitude: p.latitude, longitude: p.longitude)).toList(),
    ));
  }

  /// Cria um lançamento separado para o trecho percorrido online sem uma
  /// corrida em andamento. Os pontos são marcados depois para que nunca sejam
  /// incluídos outra vez no próximo trecho livre da mesma sessão.
  ///
  /// Sempre cria o lançamento, mesmo com km = 0 (motociclista ficou parado
  /// esperando corrida) — esse tempo parado é um dado valioso para
  /// relatórios futuros, então não pode ser descartado silenciosamente.
  Future<void> _lancarDeslocamentoLivreSeNecessario() async {
    final sessao = sessaoAtual;
    if (sessao == null) return;

    final pontos = await _repository.pontosDeDeslocamentoNaoLancados(sessao.id);
    if (pontos.isEmpty) return;

    final km = _arredondarKmGps(_geo.distanciaTotalKm(
      pontos
          .where((p) => p.aceitoNoCalculo)
          .map((p) => (latitude: p.latitude, longitude: p.longitude))
          .toList(),
    ));

    final agora = DateTime.now();
    final receitaId = _uuid.v4();
    final deslocamentoId = _uuid.v4();

    // Embarque = onde o trecho começou (ficar online, ou fim da corrida
    // anterior); destino = onde terminou (iniciar corrida, ou ficar
    // offline). Usamos as coordenadas do primeiro/último ponto GPS
    // gravados nesse trecho, já que representam exatamente esses momentos.
    // Se ficou parado (km = 0), o destino é o mesmo local do embarque —
    // não precisa geocodificar de novo.
    final enderecoInicio = await _geo.enderecoDe(pontos.first.latitude, pontos.first.longitude);
    final enderecoFim = km == 0
        ? enderecoInicio
        : await _geo.enderecoDe(pontos.last.latitude, pontos.last.longitude);
    final localEmbarque = [enderecoInicio.rua, enderecoInicio.bairro]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    final localDestino = [enderecoFim.rua, enderecoFim.bairro]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    await _receitaRepository.salvar(Receita(
      id: receitaId,
      data: agora,
      kmRodados: km,
      valorRecebido: 0,
      observacao: km == 0
          ? 'Parado aguardando corrida — lançado automaticamente pelo GPS'
          : 'Deslocamento livre — lançado automaticamente pelo GPS',
      criadoEm: agora,
      tipo: TipoReceita.deslocamentoLivre,
      localEmbarque: localEmbarque.isEmpty ? null : localEmbarque,
      localDestino: localDestino.isEmpty ? null : localDestino,
      horaInicio: pontos.first.timestamp,
      horaFim: pontos.last.timestamp,
    ));
    await _repository.salvarDeslocamentoLivre(
      id: deslocamentoId,
      sessaoId: sessao.id,
      inicio: pontos.first.timestamp,
      fim: pontos.last.timestamp,
      kmPercorrido: km,
      receitaId: receitaId,
    );
    await _repository.vincularPontosAoDeslocamento(
      pontos.map((p) => p.id).toList(),
      deslocamentoId,
    );
  }

  /// O GPS pode produzir muitas casas decimais. Mantemos precisão de metros
  /// (três casas em km) e arredondamos, em vez de truncar, o valor exibido e
  /// salvo nos lançamentos automáticos.
  double _arredondarKmGps(double km) => (km * 1000).round() / 1000;

  @override
  void dispose() {
    _timer?.cancel();
    _posicaoSubscription?.cancel();
    super.dispose();
  }
}
