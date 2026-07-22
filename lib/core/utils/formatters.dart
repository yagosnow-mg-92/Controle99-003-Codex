import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _km = NumberFormat.decimalPattern('pt_BR');
  static final _data = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _diaSemana = DateFormat('EEEE, d MMM', 'pt_BR');

  static String moeda(double valor) => _moeda.format(valor);
  static String km(double valor) => '${_km.format(valor)} km';
  static String data(DateTime data) => _data.format(data);
  static String dataExtenso(DateTime data) => _diaSemana.format(data);
  static String percentual(double valor) => '${valor.toStringAsFixed(1)}%';

  /// Formata uma duração como "5 min 40s", "1h 12min" ou "38s" — usado
  /// nos lançamentos vindos do GPS, pra mostrar quanto tempo levou aquele
  /// trecho (base pros relatórios de "tempo parado" que virão depois).
  static String duracao(Duration d) {
    final horas = d.inHours;
    final minutos = d.inMinutes.remainder(60);
    final segundos = d.inSeconds.remainder(60);

    if (horas > 0) return '${horas}h ${minutos}min';
    if (minutos > 0) return '$minutos min ${segundos}s';
    return '${segundos}s';
  }
}
