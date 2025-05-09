// lib/widgets/menu_button.dart

import 'package:flutter/material.dart';

/// Botón de menú: ancho completo, alto 48, fondo azul claro, texto negro.
class MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // espacio vertical entre botones
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBBDEFB),
            foregroundColor: Colors.black,
            elevation: 0, // Sin sombra
            shape: const StadiumBorder(), // Bordes redondeados tipo “capsula”
          ),
          child: Text(label),
        ),
      ),
    );
  }
}
