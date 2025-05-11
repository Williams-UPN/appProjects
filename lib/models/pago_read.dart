// lib/models/pago_read.dart

class PagoRead {
  final int numeroCuota;

  PagoRead({required this.numeroCuota});

  factory PagoRead.fromMap(Map<String, dynamic> m) => PagoRead(
        numeroCuota: (m['numero_cuota'] as num).toInt(),
      );
}
