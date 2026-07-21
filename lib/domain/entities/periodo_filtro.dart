enum PeriodoFiltro { dia, semana, mes, trimestre, ano, personalizado }

extension PeriodoFiltroLabel on PeriodoFiltro {
  String get label {
    switch (this) {
      case PeriodoFiltro.dia:
        return 'Dia';
      case PeriodoFiltro.semana:
        return 'Semana';
      case PeriodoFiltro.mes:
        return 'Mês';
      case PeriodoFiltro.trimestre:
        return 'Trimestre';
      case PeriodoFiltro.ano:
        return 'Ano';
      case PeriodoFiltro.personalizado:
        return 'Personalizado';
    }
  }
}
