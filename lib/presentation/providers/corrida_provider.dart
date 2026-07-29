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

  /// Tempo do "trecho" atual — zera toda vez que o trecho muda: ficar
  /// online, tocar em "mudei de local", iniciar uma corrida, ou finalizar/
  /// cancelar uma corrida (volta a contar o tempo esperando a próxima).
  /// `tempoDecorrido` continua contando o tempo total desde que ficou
  /// online, sem nunca zerar — os dois convivem lado a lado.
  Duration tempoSegmentoAtual = Duration.zero;
  DateTime? _inicioSegmentoAtual;

  String? enderecoAtual;

  Timer? _timer;
  Position? _ultimaPosicaoConhecida;

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
      _reiniciarSegmento();
    }

    carregando = false;
    notifyListeners();
  }

  /// Inicia o serviço em primeiro plano (se ainda não estiver rodando) e
  /// informa a ele qual sessão/corrida está ativa. A partir daqui, quem
  /// escuta o GPS e grava os pontos é o `_CorridaTaskHandler`, dentro do
  /// isolate do próprio serviço — não este isolate principal, que fica
  /// preso ao ciclo de vida da tela e por isso não é confiável quando
  /// outro app assume o primeiro plano.
  Future<void> _retomarRastreamento() async {
    // Salva ANTES de iniciar o serviço: o `onStart` do isolate em primeiro
    // plano lê esse dado assim que sobe, e pode rodar antes do `await`
    // abaixo terminar — não dá pra confiar na ordem entre os dois isolates.
    await ForegroundTaskService.atualizarSessao(
      sessaoId: sessaoAtual?.id,
      corridaId: corridaAtual?.id,
    );
    await ForegroundTaskService.iniciar();
    _iniciarTimer();
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (sessaoAtual != null) {
        tempoDecorrido = sessaoAtual!.duracao;
        final inicioSegmento = _inicioSegmentoAtual;
        if (inicioSegmento != null) {
          tempoSegmentoAtual = DateTime.now().difference(inicioSegmento);
        }
        notifyListeners();
      }
    });
  }

  /// Zera o cronômetro do trecho atual — chamado toda vez que um trecho
  /// termina e outro começa (ver comentário em [tempoSegmentoAtual]).
  void _reiniciarSegmento() {
    _inicioSegmentoAtual = DateTime.now();
    tempoSegmentoAtual = Duration.zero;
  }

  /// Grava, de forma pontual, a localização exata de um clique importante
  /// (ficar online, iniciar/pegar/cancelar/finalizar corrida, ficar
  /// offline). Roda no isolate principal porque só é chamada em resposta a
  /// um toque do usuário — ou seja, com o app garantidamente em primeiro
  /// plano — e sempre é aceita no cálculo (marca o início/fim exato de cada
  /// trecho, mesmo que o passo anterior daria como rejeitado por distância).
  Future<void> _registrarPosicaoAtualObrigatoria() async {
    final sessao = sessaoAtual;
    if (sessao == null) return;

    final posicao = await _geo.posicaoAtual();
    if (posicao == null) return;
    _ultimaPosicaoConhecida = posicao;

    final ponto = PontoRota(
      id: _uuid.v4(),
      sessaoId: sessao.id,
      corridaId: corridaAtual?.id,
      timestamp: DateTime.now(),
      latitude: posicao.latitude,
      longitude: posicao.longitude,
      precisaoMetros: posicao.accuracy,
      velocidadeMetrosPorSegundo: posicao.speed,
      direcaoGraus: posicao.heading,
      altitudeMetros: posicao.altitude,
      precisaoVelocidadeMetrosPorSegundo: posicao.speedAccuracy,
      localizacaoSimulada: posicao.isMocked,
      aceitoNoCalculo: true,
    );
    await _repository.registrarPontoRota(ponto);
  }

  Future<({double? lat, double? lng, String? rua, String? bairro})> _capturarLocalizacao() async {
    final posicao = _ultimaPosicaoConhecida ?? await _geo.posicaoAtual();
    if (posicao == null) return (lat: null, lng: null, rua: null, bairro: null);

    final endereco = await _geo.enderecoDe(posicao.latitude, posicao.longitude);
    return (lat: posicao.latitude, lng: posicao.longitude, rua: endereco.rua, bairro: endereco.bairro);
  }

  Future<({double? lat, double? lng, String? rua, String? bairro})> _registrarEvento(
    String sessaoId,
    TipoEvento tipo,
  ) async {
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
    return local;
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
    tempoDecorrido = Duration.zero;

    // Busca uma posição fresca ANTES de registrar o evento — é o que
    // realmente decide qual endereço fica salvo (ver comentário
    // equivalente em pegarPassageiro()).
    await _registrarPosicaoAtualObrigatoria();
    await _registrarEvento(sessao.id, TipoEvento.ficouOnline);
    await _retomarRastreamento();
    _reiniciarSegmento();

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

    // Capturado ANTES de qualquer await lento (flush do deslocamento livre,
    // busca de GPS, geocodificação) de propósito: é este horário que
    // `reivindicarPontosPorHorario` usa depois, no finalizarCorrida, como
    // limite inferior para "reclamar de volta" pontos que chegaram órfãos
    // (sem corrida_id) nessa corrida entre apertar o botão e o serviço de
    // GPS em segundo plano saber qual corrida está ativa. Se capturássemos
    // isso só depois desses awaits — que podem levar mais de um segundo —
    // pontos que vazaram bem no início ficariam de fora dessa reivindicação
    // e sobrariam pro próximo deslocamento livre, criando um lançamento
    // fantasma que reaproveita o trajeto desta própria corrida.
    final horaInicio = DateTime.now();

    // Tudo que foi percorrido enquanto estava online, antes de aceitar esta
    // corrida, é um deslocamento sem remuneração e precisa ficar separado da
    // receita da corrida.
    await _lancarDeslocamentoLivreSeNecessario();

    // Busca uma posição fresca ANTES de registrar o evento — sem isso, o
    // endereço usado seria a última posição recebida pelo stream em
    // segundo plano (que só atualiza a cada alguns metros/segundos e pode
    // estar atrasada), não onde o motociclista está agora.
    await _registrarPosicaoAtualObrigatoria();
    // Este é o local de INÍCIO — o motociclista ainda está a caminho do
    // passageiro. O local de embarque de verdade só é gravado em
    // pegarPassageiro(); se a corrida for cancelada antes disso, o
    // embarque fica vazio de propósito (nunca aconteceu).
    final localInicio = await _registrarEvento(sessaoAtual!.id, TipoEvento.iniciouCorrida);

    final corrida = await _repository.criarCorrida(
      sessaoId: sessaoAtual!.id,
      horaInicio: horaInicio,
      valor: valor,
    );
    corridaAtual = corrida.copyWith(
      localInicio: enderecoAtual,
      localInicioLat: localInicio.lat,
      localInicioLng: localInicio.lng,
    );
    await _repository.atualizarLocalInicio(
      corrida.id,
      local: enderecoAtual,
      lat: localInicio.lat,
      lng: localInicio.lng,
    );
    await ForegroundTaskService.atualizarSessao(
      sessaoId: sessaoAtual!.id,
      corridaId: corridaAtual!.id,
    );

    await _repository.atualizarStatusSessao(sessaoAtual!.id, StatusSessao.corridaIniciada);
    sessaoAtual = sessaoAtual!.copyWith(status: StatusSessao.corridaIniciada);

    await ForegroundTaskService.atualizarNotificacao('Corrida em andamento.');
    _reiniciarSegmento();

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
    final localFim = await _registrarEvento(sessaoAtual!.id, TipoEvento.cancelouCorrida);
    final enderecoFim = enderecoAtual;

    final horaFimCorrida = DateTime.now();
    // Mesma correção de finalizarCorrida: reivindica por horário os pontos
    // que ficaram sem corrida_id pela corrida entre "iniciar corrida" e o
    // serviço de GPS processar o aviso.
    await _repository.reivindicarPontosPorHorario(
      corridaId: corridaAtual!.id,
      sessaoId: sessaoAtual!.id,
      inicio: corridaAtual!.horaInicio,
      fim: horaFimCorrida,
    );
    final km = await _calcularKmDaCorrida(corridaAtual!.id);
    await _repository.atualizarValorCorrida(corridaAtual!.id, valorTaxa, cancelada: true);
    await _repository.finalizarCorrida(
      corridaAtual!.id,
      horaFimCorrida,
      km,
      localDestino: enderecoFim,
      localDestinoLat: localFim.lat,
      localDestinoLng: localFim.lng,
    );

    final receitaId = _uuid.v4();
    final receita = Receita(
      id: receitaId,
      data: DateTime.now(),
      kmRodados: km,
      valorRecebido: valorTaxa,
      observacao: 'Taxa de cancelamento — lançado automaticamente pela função Corrida',
      criadoEm: DateTime.now(),
      localInicio: corridaAtual!.localInicio,
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
    await ForegroundTaskService.atualizarSessao(sessaoId: sessaoAtual!.id, corridaId: null);

    await ForegroundTaskService.atualizarNotificacao('Você está online — procurando corrida.');
    _reiniciarSegmento();

    processando = false;
    notifyListeners();
  }

  /// Peguei o passageiro — a corrida continua, só muda o status visual.
  /// Esse é o endereço que vira "local de embarque" no lançamento final.
  Future<void> pegarPassageiro() async {
    if (sessaoAtual == null || corridaAtual == null) return;
    processando = true;
    notifyListeners();

    // Sem isso, o endereço registrado ficava sendo a última posição
    // recebida pelo stream em segundo plano (que só atualiza a cada
    // alguns metros e pode estar atrasada) em vez de onde o motociclista
    // está agora — o mesmo motivo pelo qual todo outro clique importante
    // (ficar online, iniciar/cancelar/finalizar corrida) já busca uma
    // posição fresca antes de registrar o evento.
    await _registrarPosicaoAtualObrigatoria();
    final localEmbarque = await _registrarEvento(sessaoAtual!.id, TipoEvento.pegouPassageiro);
    final enderecoEmbarque = enderecoAtual;

    if (enderecoEmbarque != null) {
      await _repository.atualizarLocalEmbarque(
        corridaAtual!.id,
        local: enderecoEmbarque,
        lat: localEmbarque.lat,
        lng: localEmbarque.lng,
      );
      corridaAtual = corridaAtual!.copyWith(
        localEmbarque: enderecoEmbarque,
        localEmbarqueLat: localEmbarque.lat,
        localEmbarqueLng: localEmbarque.lng,
      );
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
    final localFim = await _registrarEvento(sessaoAtual!.id, TipoEvento.finalizouCorrida);
    final enderecoFim = enderecoAtual;

    final horaFimCorrida = DateTime.now();
    // Reivindica, por horário, qualquer ponto que tenha ficado sem
    // corrida_id por causa da corrida entre o aviso "iniciar corrida" e o
    // serviço de GPS processá-lo — sem isso, esses pontos vazam pro
    // próximo cálculo de deslocamento livre e criam um lançamento fantasma.
    await _repository.reivindicarPontosPorHorario(
      corridaId: corridaAtual!.id,
      sessaoId: sessaoAtual!.id,
      inicio: corridaAtual!.horaInicio,
      fim: horaFimCorrida,
    );
    final km = await _calcularKmDaCorrida(corridaAtual!.id);
    await _repository.finalizarCorrida(
      corridaAtual!.id,
      horaFimCorrida,
      km,
      localDestino: enderecoFim,
      localDestinoLat: localFim.lat,
      localDestinoLng: localFim.lng,
    );

    final receitaId = _uuid.v4();
    final receita = Receita(
      id: receitaId,
      data: DateTime.now(),
      kmRodados: km,
      valorRecebido: corridaAtual!.valor,
      observacao: 'Lançado automaticamente pela função Corrida',
      criadoEm: DateTime.now(),
      localInicio: corridaAtual!.localInicio,
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
    await ForegroundTaskService.atualizarSessao(sessaoId: sessaoAtual!.id, corridaId: null);

    await ForegroundTaskService.atualizarNotificacao('Você está online — procurando corrida.');
    _reiniciarSegmento();

    processando = false;
    notifyListeners();
  }

  /// "Mudei de local" — só faz sentido no estado online, sem corrida em
  /// andamento (mesmos botões que "Iniciar corrida" e "Ficar offline").
  /// Fecha o trecho atual exatamente como se tivesse ficado offline e
  /// online de novo: lança o que foi percorrido até agora como um
  /// deslocamento livre (valor zero) e reinicia o cronômetro do trecho —
  /// sem, no entanto, encerrar a sessão. Serve pra separar, no relatório,
  /// quanto tempo foi gasto esperando corrida em cada ponto diferente.
  Future<void> mudarDeLocal() async {
    if (sessaoAtual == null || corridaAtual != null) return;
    processando = true;
    notifyListeners();

    await _registrarPosicaoAtualObrigatoria();
    await _lancarDeslocamentoLivreSeNecessario();
    await _registrarEvento(sessaoAtual!.id, TipoEvento.mudouLocal);
    _reiniciarSegmento();

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
    await ForegroundTaskService.parar();

    sessaoAtual = null;
    corridaAtual = null;
    tempoDecorrido = Duration.zero;

    processando = false;
    notifyListeners();
  }

  Future<double> _calcularKmDaCorrida(String corridaId) async {
    // O mapa mostra a trilha bruta. Recalculamos usando essa mesma trilha,
    // com uma validação de segmentos tolerante a GPS urbano, para não haver
    // quilômetros visíveis no mapa que desaparecem do lançamento financeiro.
    final pontos = await _repository.todosPontosDaCorrida(corridaId);
    return _arredondarKmGps(_geo.distanciaDaTrilhaKm(pontos));
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

    final km = _arredondarKmGps(_geo.distanciaDaTrilhaKm(pontos));

    final agora = DateTime.now();
    final receitaId = _uuid.v4();
    final deslocamentoId = _uuid.v4();

    // Início = onde o trecho começou (ficar online, ou fim da corrida
    // anterior); destino = onde terminou (iniciar corrida, ou ficar
    // offline). Usamos as coordenadas do primeiro/último ponto GPS
    // gravados nesse trecho, já que representam exatamente esses momentos.
    // Não existe "local de embarque" aqui — deslocamento livre nunca tem
    // passageiro, só corrida de fato tem esse campo preenchido.
    // Se ficou parado (km = 0), o destino é o mesmo local do início —
    // não precisa geocodificar de novo.
    final enderecoInicio = await _geo.enderecoDe(pontos.first.latitude, pontos.first.longitude);
    final enderecoFim = km == 0
        ? enderecoInicio
        : await _geo.enderecoDe(pontos.last.latitude, pontos.last.longitude);
    final localInicio = [enderecoInicio.rua, enderecoInicio.bairro]
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
      localInicio: localInicio.isEmpty ? null : localInicio,
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
    super.dispose();
  }
}
