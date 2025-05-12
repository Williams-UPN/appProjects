import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cronograma_read.dart';

/// Grid de botones para cada cuota, ahora mostrando solo día y mes
class CuotasGrid extends StatelessWidget {
  final int dias;
  final List<CronogramaRead> cronograma;
  final int? cuotaSeleccionada;
  final int siguienteCuotaValida;
  final DateTime fechaInicio;
  final void Function(int) onSeleccionar;

  const CuotasGrid({
    super.key,
    required this.dias,
    required this.cronograma,
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
      shrinkWrap: true, // ← Nuevo
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

        final pago = cronograma.firstWhere(
          (c) => c.numeroCuota == numCuota,
          orElse: () => CronogramaRead(
            numeroCuota: numCuota,
            montoCuota: 0,
            fechaPagado: null,
          ),
        );
        final estaPag = pago.fechaPagado != null;
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
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check, color: Colors.deepPurple),
                      const SizedBox(height: 4),
                      Text(
                        // Solo día y mes:
                        DateFormat('dd/MM').format(pago.fechaPagado!),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  )
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
