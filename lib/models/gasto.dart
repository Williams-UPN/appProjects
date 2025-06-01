// lib/models/gasto.dart

class Gasto {
  final String categoria;
  final double monto;
  final String? descripcion;
  final String? fotoUrl;
  final double? latitud;
  final double? longitud;
  final DateTime? fechaGasto;

  Gasto({
    required this.categoria,
    required this.monto,
    this.descripcion,
    this.fotoUrl,
    this.latitud,
    this.longitud,
    this.fechaGasto,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'categoria': categoria,
      'monto': monto,
    };

    if (descripcion != null && descripcion!.trim().isNotEmpty) {
      data['descripcion'] = descripcion!.trim();
    }

    if (fotoUrl != null) {
      data['foto_url'] = fotoUrl;
    }

    if (latitud != null) {
      data['latitud'] = latitud;
    }

    if (longitud != null) {
      data['longitud'] = longitud;
    }

    if (fechaGasto != null) {
      data['fecha_gasto'] = fechaGasto!.toIso8601String().split('T').first;
    }

    return data;
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      categoria: map['categoria'] as String,
      monto: (map['monto'] as num).toDouble(),
      descripcion: map['descripcion'] as String?,
      fotoUrl: map['foto_url'] as String?,
      latitud: (map['latitud'] as num?)?.toDouble(),
      longitud: (map['longitud'] as num?)?.toDouble(),
      fechaGasto: map['fecha_gasto'] != null
          ? DateTime.parse(map['fecha_gasto'] as String)
          : null,
    );
  }
}
