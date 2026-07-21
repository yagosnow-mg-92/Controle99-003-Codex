enum PeriodoDashboard { dia, semana, mes, personalizado }

extension PeriodoDashboardLabel on PeriodoDashboard {
  String get label {
    switch (this) {
      case PeriodoDashboard.dia:
        return 'Dia atual';
      case PeriodoDashboard.semana:
        return 'Semana atual';
      case PeriodoDashboard.mes:
        return 'Mês atual';
      case PeriodoDashboard.personalizado:
        return 'Personalizado';
    }
  }

  String get labelCurto {
    switch (this) {
      case PeriodoDashboard.dia:
        return 'Dia';
      case PeriodoDashboard.semana:
        return 'Semana';
      case PeriodoDashboard.mes:
        return 'Mês';
      case PeriodoDashboard.personalizado:
        return 'Período';
    }
  }
}
