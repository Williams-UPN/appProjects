// lib/models/cliente.dart

class Cliente {
  final String nombre;
  final String telefono;
  final String direccion;
  final String negocio;
  final int montoSolicitado;
  final int plazoDias;
  final DateTime fechaPrimerPago;

  Cliente({
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.negocio,
    required this.montoSolicitado,
    required this.plazoDias,
    required this.fechaPrimerPago,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'telefono': telefono,
        'direccion': direccion,
        'negocio': negocio,
        'monto_solicitado': montoSolicitado,
        'plazo_dias': plazoDias,
        'fecha_primer_pago': fechaPrimerPago.toUtc().toIso8601String(),
      };
}
