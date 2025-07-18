import 'package:flutter/material.dart';
import 'package:proyecto/widgets/menu_button.dart';
import '../../main.dart';

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
            if (appConfig != null && appConfig!['cobrador_nombre'] != 'PLACEHOLDER_NOMBRE')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF90CAF9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Sesión activa',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appConfig!['cobrador_nombre'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    Text(
                      'DNI: ${appConfig!['cobrador_dni']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
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
