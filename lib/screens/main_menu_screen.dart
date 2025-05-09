import 'package:flutter/material.dart';
import 'cliente_nuevo/cliente_nuevo_screen.dart';
import 'lista_de_clientes/lista_de_clientes_screen.dart';
import 'cliente_pendiente/cliente_pendiente_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  // Define el color claro y el estilo del botón una sola vez
  static final Color azulClaroSuave = const Color(0xFFBBDEFB);
  static final ButtonStyle estiloBoton = ElevatedButton.styleFrom(
    backgroundColor: azulClaroSuave,
    foregroundColor: const Color.fromARGB(255, 7, 0, 0),
  );

  // Función que devuelve un botón con estilo ya configurado
  Widget customButton(String texto, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: estiloBoton,
      child: Text(texto),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Menú principal',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            customButton('Cliente Cercano', () {
              // Navegación pendiente
            }),
            customButton('Lista de Clientes', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ListaDeClientesScreen(),
                ),
              );
            }),
            customButton('Cliente Nuevo', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClienteNuevoScreen(),
                ),
              );
            }),
            customButton('Clientes Pendientes', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientesPendientesScreen(),
                ),
              );
            }),
            customButton('Agregar Gastos', () {
              // Acción pendiente
            }),
            customButton('Reportes', () {
              // Acción pendiente
            }),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
