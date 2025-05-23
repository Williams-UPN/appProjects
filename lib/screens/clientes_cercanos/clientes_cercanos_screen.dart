// lib/screens/clientes_cercanos/clientes_cercanos_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/clientes_cercanos_viewmodel.dart'; // Ajusta la ruta
import '../../models/cliente_read.dart'; // Ajusta la ruta
import '../../widgets/relief_star.dart'; // Asumiendo que tienes este widget
import '../tarjeta_cliente/tarjeta_cliente_screen.dart'; // Ajusta la ruta

class ClientesCercanosScreen extends StatefulWidget {
  const ClientesCercanosScreen({super.key});

  @override
  State<ClientesCercanosScreen> createState() => _ClientesCercanosScreenState();
}

class _ClientesCercanosScreenState extends State<ClientesCercanosScreen> {
  @override
  void initState() {
    super.initState();
    // Usar addPostFrameCallback para asegurar que el context esté disponible
    // y se llame después de que el primer frame haya sido construido.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Cargar los clientes cercanos al iniciar la pantalla.
      // Puedes pasar un radio en km si quieres filtrar, o 0 para mostrar todos ordenados.
      Provider.of<ClientesCercanosViewModel>(context, listen: false)
          .cargarClientesCercanos(
              maxDistanciaKmParaFiltrar: 10.0); // Ejemplo: Radio de 10km
    });
  }

  // Funciones de ayuda para el estilo (similares a ClientesPendientesScreen)
  // Puedes moverlas a un archivo de utils si las usas en múltiples lugares.
  int _scoreToStars(int score) {
    //
    if (score >= 90) return 5;
    if (score >= 75) return 4;
    if (score >= 50) return 3;
    if (score >= 25) return 2;
    if (score >= 1) return 1;
    return 0;
  }

  String _labelParaScore(int score) {
    //
    if (score >= 90) return 'Excelente';
    if (score >= 75) return 'Buen pagador';
    if (score >= 50) return 'Riesgo medio';
    if (score >= 25) return 'Riesgo alto';
    return 'Incumplidor';
  }

  Color _colorParaScore(int score) {
    //
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    if (score >= 25) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClientesCercanosViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes Cercanos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              vm.cargarClientesCercanos(
                  maxDistanciaKmParaFiltrar:
                      10000.0); // Usando el default grande
            },
            tooltip: 'Actualizar ubicación y lista',
          )
        ],
      ),
      body: Builder(
        builder: (context) {
          if (vm.estaCargando) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.mensajeError != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Error: ${vm.mensajeError}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }

          if (vm.clientesOrdenadosPorDistancia.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No hay clientes cercanos según el criterio actual, o no se pudo obtener la lista.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: vm.clientesOrdenadosPorDistancia.length,
            itemBuilder: (context, index) {
              final clienteConDistancia =
                  vm.clientesOrdenadosPorDistancia[index];
              final ClienteRead c = clienteConDistancia.cliente;
              final distanciaMetros = clienteConDistancia.distanciaMetros;

              String distanciaFormateada;
              if (distanciaMetros < 1000) {
                distanciaFormateada = "${distanciaMetros.toStringAsFixed(0)} m";
              } else {
                distanciaFormateada =
                    "${(distanciaMetros / 1000).toStringAsFixed(1)} km";
              }

              final stars = _scoreToStars(c.scoreActual);
              final scoreLabel =
                  c.hasHistory ? _labelParaScore(c.scoreActual) : '¡nuevo!';
              final scoreColor =
                  c.hasHistory ? _colorParaScore(c.scoreActual) : Colors.grey;

              return Card(
                // ---------- INICIO DE MODIFICACIÓN ----------
                color: Colors.blue
                    .shade50, // MISMO COLOR QUE LAS OTRAS PANTALLAS DE LISTA
                // ---------- FIN DE MODIFICACIÓN ----------
                margin: const EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2, // Mantener una elevación sutil similar
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TarjetaClienteScreen(clienteId: c.id),
                      ),
                    ).then((_) {
                      // Opcional: Recargar o actualizar algo al volver
                    });
                  },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(c.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (j) {
                          return ReliefStar(filled: j < stars, size: 16);
                        }),
                      ),
                    ],
                  ),
                  subtitle: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment
                                .center, // Para mejor alineación vertical
                            children: [
                              Text('Tel: ${c.telefono}'),
                              Text('Dir: ${c.direccion}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('Neg: ${c.negocio}',
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment
                                .spaceBetween, // Para distribuir el espacio
                            children: [
                              Text(
                                scoreLabel,
                                style:
                                    TextStyle(color: scoreColor, fontSize: 12),
                              ),
                              const SizedBox(height: 4), // Pequeño espacio
                              Column(
                                // Agrupar "Distancia" y el valor
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Distancia:',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700),
                                  ),
                                  Text(
                                    distanciaFormateada,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors
                                          .deepPurple, // Color distintivo para la distancia
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  isThreeLine:
                      true, // Ajusta esto si el contenido realmente ocupa tres líneas o más.
                  // Puede que con la info de distancia sea más bien `false` o dependerá del largo de la dirección.
                  // Pruébalo y ajusta a `false` si se ve mejor.
                ),
              );
            },
          );
        },
      ),
    );
  }
}
