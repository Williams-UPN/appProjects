// lib/widgets/cuotas_grid.dart

import 'package:flutter/material.dart';

/// Grid de botones para cada cuota
class CuotasGrid extends StatelessWidget {
  final int dias;
  final List<int> cuotasPagadas;
  final int? cuotaSeleccionada;
  final int siguienteCuotaValida;
  final DateTime fechaInicio;
  final void Function(int) onSeleccionar;

  const CuotasGrid({
    super.key,
    required this.dias,
    required this.cuotasPagadas,
    required this.cuotaSeleccionada,
    required this.siguienteCuotaValida,
    required this.fechaInicio,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    const columnas = 6;
    final hoy = DateTime.now();
    final today = DateTime(hoy.year, hoy.month, hoy.day);

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dias,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (_, idx) {
        final numCuota = idx + 1;
        final dueDate = DateTime(
          fechaInicio.year,
          fechaInicio.month,
          fechaInicio.day + idx,
        );

        final estaPag = cuotasPagadas.contains(numCuota);
        final sel = cuotaSeleccionada == numCuota;
        final esHoy = dueDate == today;
        final esProx = numCuota == 1 && fechaInicio.isAfter(today) && !estaPag;
        final vencida = dueDate.isBefore(today) && !estaPag;

        Color bg;
        Color border;
        if (estaPag) {
          bg = Colors.grey[300]!;
          border = Colors.transparent;
        } else if (esHoy) {
          bg = Colors.orange[100]!;
          border = Colors.orange;
        } else if (esProx) {
          bg = Colors.blue[100]!;
          border = Colors.blue;
        } else if (vencida) {
          bg = Colors.red[100]!;
          border = Colors.red;
        } else if (sel) {
          bg = Colors.blue[100]!;
          border = Colors.blue;
        } else {
          bg = Colors.white;
          border = Colors.grey;
        }

        return GestureDetector(
          onTap: estaPag ? null : () => onSeleccionar(numCuota),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: estaPag
                ? const Icon(Icons.check, color: Colors.deepPurple)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$numCuota'),
                      if (esHoy)
                        const Text(
                          'HOY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (esProx)
                        const Text(
                          'PRÓXIMO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
