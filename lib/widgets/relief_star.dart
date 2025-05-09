import 'package:flutter/material.dart';

/// Un widget que dibuja una estrella con efecto de relieve.
/// - [filled]: si es `true`, la estrella va llena de color; si no, solo contorno.
/// - [size]: tamaño en píxeles.
class ReliefStar extends StatelessWidget {
  final bool filled;
  final double size;

  const ReliefStar({
    super.key, // usamos super.key
    this.filled = false,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    // Dos capas de Icon superpuestas con sombras para crear relieve:
    return Stack(
      alignment: Alignment.center,
      children: [
        // Sombra “interna” clara (usando withAlpha en lugar de withOpacity)
        Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: Colors.white.withAlpha((0.6 * 255).round()),
        ),
        // Sombra “interna” oscura, desplazada ligeramente
        Positioned(
          top: 1,
          left: 1,
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            size: size,
            color: Colors.black.withAlpha((0.2 * 255).round()),
          ),
        ),
        // La estrella real encima
        Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: filled ? Colors.amber : Colors.grey.shade400,
        ),
      ],
    );
  }
}
