// lib/models/historial_read.dart

class HistorialRead {
  final DateTime? fechaInicio;  // Ahora es nullable
  final DateTime? fechaCierreReal;
  final num montoSolicitado;
  final num totalPagado;
  final int diasTotales;
  final int diasAtrasoMax;

  HistorialRead({
    this.fechaInicio,  // Ya no es required
    this.fechaCierreReal,
    required this.montoSolicitado,
    required this.totalPagado,
    required this.diasTotales,
    required this.diasAtrasoMax,
  });

  factory HistorialRead.fromMap(Map<String, dynamic> m) => HistorialRead(
        fechaInicio: m['fecha_inicio'] == null
            ? null
            : DateTime.parse(m['fecha_inicio'] as String),
        fechaCierreReal: m['fecha_cierre_real'] == null
            ? null
            : DateTime.parse(m['fecha_cierre_real'] as String),
        montoSolicitado: m['monto_solicitado'] as num,
        totalPagado: m['total_pagado'] as num,
        diasTotales: (m['dias_totales'] as num).toInt(),
        diasAtrasoMax: (m['dias_atraso_max'] as num).toInt(),
      );
}
