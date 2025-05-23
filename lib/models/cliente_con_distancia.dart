// lib/models/cliente_con_distancia.dart

import 'cliente_read.dart'; // Asegúrate que la ruta a tu modelo ClienteRead sea correcta

class ClienteConDistancia {
  final ClienteRead cliente;
  final double distanciaMetros;

  ClienteConDistancia({
    required this.cliente,
    required this.distanciaMetros,
  });
}
