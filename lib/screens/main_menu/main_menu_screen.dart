import 'package:flutter/material.dart';
import 'package:proyecto/widgets/menu_button.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        // Reemplazamos withOpacity por Color.fromRGBO:
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            MenuButton(
              label: 'Cliente Cercano',
              onTap: () => Navigator.pushNamed(context, '/clientes_cercanos'),
            ),
            MenuButton(
              label: 'Lista de Clientes',
              onTap: () => Navigator.pushNamed(context, '/lista'),
            ),
            MenuButton(
              label: 'Cliente Nuevo',
              onTap: () => Navigator.pushNamed(context, '/nuevo'),
            ),
            MenuButton(
              label: 'Clientes Pendientes',
              onTap: () => Navigator.pushNamed(context, '/pendientes'),
            ),
            MenuButton(
              label: 'Agregar Gastos',
              onTap: () => Navigator.pushNamed(context, '/agregar_gastos'),
            ),
            MenuButton(
              label: 'Reportes',
              onTap: () => Navigator.pushNamed(context, '/reportes'),
            ),
          ],
        ),
      ),
    );
  }
}
