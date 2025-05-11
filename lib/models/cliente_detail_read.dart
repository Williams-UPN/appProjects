class ClienteDetailRead {
  final int id;
  final String nombre;
  final String telefono;
  final String direccion;
  final String negocio;
  final String estadoReal;
  final int diasReales;
  final int scoreActual;
  final bool hasHistory;

  // Campos extra para detalle
  final num montoSolicitado; // <-- nuevo
  final DateTime fechaPrimerPago;
  final num cuotaDiaria;
  final num ultimaCuota;
  final int plazoDias;
  final num saldoPendiente;

  ClienteDetailRead({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.negocio,
    required this.estadoReal,
    required this.diasReales,
    required this.scoreActual,
    required this.hasHistory,
    required this.montoSolicitado, // <-- nuevo
    required this.fechaPrimerPago,
    required this.cuotaDiaria,
    required this.ultimaCuota,
    required this.plazoDias,
    required this.saldoPendiente,
  });

  factory ClienteDetailRead.fromMap(Map<String, dynamic> m) {
    // parseamos la fecha de primer pago
    final rawPrimer = DateTime.parse(m['fecha_primer_pago'] as String);
    final fechaPrimer = DateTime(
      rawPrimer.year,
      rawPrimer.month,
      rawPrimer.day,
    );

    return ClienteDetailRead(
      id: m['id'] as int,
      nombre: m['nombre'] as String,
      telefono: m['telefono'] as String,
      direccion: m['direccion'] as String,
      negocio: m['negocio'] as String? ?? '',
      estadoReal: m['estado_real'] as String,
      diasReales: (m['dias_reales'] as num).toInt(),
      scoreActual: (m['score_actual'] as num).toInt(),
      hasHistory: m['has_history'] as bool,

      // ------ aquí el nuevo campo ------
      montoSolicitado: m['monto_solicitado'] as num,

      fechaPrimerPago: fechaPrimer,
      cuotaDiaria: m['cuota_diaria'] as num,
      ultimaCuota: m['ultima_cuota'] as num,
      plazoDias: (m['plazo_dias'] as num).toInt(),
      saldoPendiente: m['saldo_pendiente'] as num,
    );
  }
}
