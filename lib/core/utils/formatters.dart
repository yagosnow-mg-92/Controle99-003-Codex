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
}
