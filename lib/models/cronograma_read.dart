// lib/models/cronograma_read.dart

class CronogramaRead {
  final int numeroCuota;
  final num montoCuota;
  final DateTime? fechaPagado;

  CronogramaRead({
    required this.numeroCuota,
    required this.montoCuota,
    this.fechaPagado,
  });

  factory CronogramaRead.fromMap(Map<String, dynamic> m) => CronogramaRead(
        numeroCuota: (m['numero_cuota'] as num).toInt(),
        montoCuota: m['monto_cuota'] as num,
        fechaPagado: m['fecha_pagado'] == null
            ? null
            : DateTime.parse(m['fecha_pagado'] as String),
      );
}
