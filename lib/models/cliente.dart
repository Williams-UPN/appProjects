// lib/models/cliente.dart

class Cliente {
  final String nombre;
  final String telefono;
  final String
      direccion; // Podrías decidir si este campo sigue siendo obligatorio o se llena desde el mapa
  final String negocio;
  final int montoSolicitado;
  final int plazoDias;
  final DateTime fechaPrimerPago;
  final double? latitud; // Nuevo campo
  final double? longitud; // Nuevo campo

  Cliente({
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.negocio,
    required this.montoSolicitado,
    required this.plazoDias,
    required this.fechaPrimerPago,
    this.latitud, // Añadido al constructor
    this.longitud, // Añadido al constructor
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'nombre': nombre,
      'telefono': telefono,
      'direccion': direccion,
      'negocio': negocio,
      'monto_solicitado': montoSolicitado,
      'plazo_dias': plazoDias,
      'fecha_primer_pago': fechaPrimerPago.toUtc().toIso8601String(),
    };

    if (latitud != null) {
      data['latitud'] = latitud;
    }
    if (longitud != null) {
      data['longitud'] = longitud;
    }
    return data;
  }
}
