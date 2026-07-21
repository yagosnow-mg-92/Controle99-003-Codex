class Configuracoes {
  final String motoModelo;
  final String motoAno;
  final double consumoMedioKmL;
  final double valorGasolina;
  final double metaDiaria;
  final double metaSemanal;
  final double metaMensal;

  const Configuracoes({
    this.motoModelo = '',
    this.motoAno = '',
    this.consumoMedioKmL = 0,
    this.valorGasolina = 0,
    this.metaDiaria = 0,
    this.metaSemanal = 0,
    this.metaMensal = 0,
  });

  Configuracoes copyWith({
    String? motoModelo,
    String? motoAno,
    double? consumoMedioKmL,
    double? valorGasolina,
    double? metaDiaria,
    double? metaSemanal,
    double? metaMensal,
  }) {
    return Configuracoes(
      motoModelo: motoModelo ?? this.motoModelo,
      motoAno: motoAno ?? this.motoAno,
      consumoMedioKmL: consumoMedioKmL ?? this.consumoMedioKmL,
      valorGasolina: valorGasolina ?? this.valorGasolina,
      metaDiaria: metaDiaria ?? this.metaDiaria,
      metaSemanal: metaSemanal ?? this.metaSemanal,
      metaMensal: metaMensal ?? this.metaMensal,
    );
  }
}
