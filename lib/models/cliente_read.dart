// lib/models/cliente_read.dart

class ClienteRead {
  final int id;
  final String nombre;
  final String telefono;
  final String direccion;
  final String negocio;
  final String estadoReal;
  final int diasReales;
  final int scoreActual;
  final bool hasHistory;

  ClienteRead({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.negocio,
    required this.estadoReal,
    required this.diasReales,
    required this.scoreActual,
    required this.hasHistory,
  });

  factory ClienteRead.fromMap(Map<String, dynamic> m) => ClienteRead(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        telefono: m['telefono'] as String,
        direccion: m['direccion'] as String,
        negocio: m['negocio'] as String? ?? '',
        estadoReal: m['estado_real'] as String,
        diasReales: (m['dias_reales'] as num).toInt(),
        scoreActual: (m['score_actual'] as num).toInt(),
        hasHistory: m['has_history'] as bool,
      );
}
