// lib/models/cliente_detail_read.dart

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
  final num montoSolicitado;
  final DateTime fechaPrimerPago;
  final num cuotaDiaria;
  final num ultimaCuota;
  final int plazoDias;
  final num saldoPendiente;
  final double? latitud; // Nuevo campo
  final double? longitud; // Nuevo campo

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
    required this.montoSolicitado,
    required this.fechaPrimerPago,
    required this.cuotaDiaria,
    required this.ultimaCuota,
    required this.plazoDias,
    required this.saldoPendiente,
    this.latitud, // Añadido al constructor
    this.longitud, // Añadido al constructor
  });

  factory ClienteDetailRead.fromMap(Map<String, dynamic> m) {
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
      negocio: (m['negocio'] as String?) ?? '',
      estadoReal: m['estado_real'] as String,
      diasReales: (m['dias_reales'] as num).toInt(),
      scoreActual: (m['score_actual'] as num).toInt(),
      hasHistory: m['has_history'] as bool,
      montoSolicitado: m['monto_solicitado'] as num,
      fechaPrimerPago: fechaPrimer,
      cuotaDiaria: m['cuota_diaria'] as num,
      ultimaCuota: m['ultima_cuota'] as num,
      plazoDias: (m['plazo_dias'] as num).toInt(),
      saldoPendiente: m['saldo_pendiente'] as num,
      latitud: (m['latitud'] as num?)?.toDouble(), // Lectura del nuevo campo
      longitud: (m['longitud'] as num?)?.toDouble(), // Lectura del nuevo campo
    );
  }
}
