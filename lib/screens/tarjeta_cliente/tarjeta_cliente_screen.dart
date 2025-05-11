// lib/screens/tarjeta_cliente/tarjeta_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cliente_detail_read.dart';
import '../../models/cronograma_read.dart';
import '../../models/historial_read.dart';
import '../../viewmodels/tarjeta_cliente_viewmodel.dart';
import '../../widgets/info_row.dart';
import '../../widgets/cuotas_grid.dart';

class TarjetaClienteScreen extends StatefulWidget {
  final int clienteId;
  const TarjetaClienteScreen({super.key, required this.clienteId});

  @override
  State<TarjetaClienteScreen> createState() => _TarjetaClienteScreenState();
}

class _TarjetaClienteScreenState extends State<TarjetaClienteScreen> {
  late final TarjetaClienteViewModel _vm;

  @override
  void initState() {
    super.initState();
    // Leemos el VM y disparar carga de datos
    _vm = context.read<TarjetaClienteViewModel>();
    _vm.loadData(widget.clienteId);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TarjetaClienteViewModel>();

    if (vm.isLoading || vm.cliente == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ClienteDetailRead c = vm.cliente!;
    final pagos = vm.pagos.map((p) => p.numeroCuota).toList();
    final cronograma = vm.cronograma;
    final historial = vm.historial;
    final cuotaSeleccionada = vm.cuotaSeleccionada;

    // Siguiente cuota válida
    final siguienteCuotaValida =
        pagos.isEmpty ? 1 : pagos.reduce((a, b) => a > b ? a : b) + 1;

    String estadoLabel(String raw, int diasAtraso) {
      switch (raw) {
        case 'proximo':
          return 'Pago próximo';
        case 'completo':
          return 'Completado';
        case 'atrasado':
          return '$diasAtraso día(s) de atraso';
        case 'pendiente':
          return 'Pago pendiente hoy';
        default:
          return 'Al día';
      }
    }

    Color estadoColor(String raw) {
      switch (raw) {
        case 'proximo':
          return Colors.blue;
        case 'pendiente':
          return Colors.orange;
        case 'atrasado':
          return Colors.red;
        case 'completo':
          return Colors.green;
        default:
          return Colors.green;
      }
    }

    // Datos de la cuota seleccionada
    final cuotaData = cronograma.firstWhere(
      (r) => r.numeroCuota == cuotaSeleccionada,
      orElse: () => CronogramaRead(
        numeroCuota: 0,
        montoCuota: c.cuotaDiaria,
        fechaPagado: null,
      ),
    );
    final displayCuota = cuotaData.montoCuota;
    final label = estadoLabel(c.estadoReal, c.diasReales);
    final color = estadoColor(c.estadoReal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Cliente'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre y negocio
            Text(
              c.nombre,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (c.negocio.isNotEmpty)
              Text(c.negocio, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),

            // Card de datos financieros
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Monto prestado:',
                    value: 'S/${c.montoSolicitado}',
                    color: Colors.green,
                  ),
                  InfoRow(
                    label: 'Saldo pendiente:',
                    value: 'S/${c.saldoPendiente.toStringAsFixed(2)}',
                    color: Colors.red,
                  ),
                  InfoRow(
                    label: 'Cuota diaria:',
                    value: 'S/${displayCuota.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.justify,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Grid de cuotas
            Expanded(
              child: CuotasGrid(
                dias: c.plazoDias,
                cuotasPagadas: pagos,
                cuotaSeleccionada: cuotaSeleccionada,
                siguienteCuotaValida: siguienteCuotaValida,
                fechaInicio: c.fechaPrimerPago,
                onSeleccionar: (n) {
                  if (n != siguienteCuotaValida) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Debes pagar la cuota anterior para continuar',
                        ),
                        duration: Duration(milliseconds: 800),
                      ),
                    );
                    return;
                  }
                  vm.selectCuota(n);
                },
              ),
            ),

            // Botones estáticos: Llamar, Ubicación, Refinanciar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone, size: 20),
                    label: const Text('Llamar'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.location_on, size: 20),
                    label: const Text('Ubicación'),
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Refinanciar'),
                  ),
                ],
              ),
            ),

            // Ver historial
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: GestureDetector(
                onTap: c.estadoReal == 'completo'
                    ? () {
                        if (historial != null) {
                          _showHistorialDialog(context, historial);
                        }
                      }
                    : null,
                child: Opacity(
                  opacity: c.estadoReal == 'completo' ? 1.0 : 0.5,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.history, color: Colors.black54),
                      SizedBox(width: 8),
                      Text(
                        'Ver Historial del Cliente',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botón Registrar pago
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cuotaSeleccionada == siguienteCuotaValida
                    ? () async {
                        final obs = await _showConfirmDialog(
                            context, displayCuota, cuotaSeleccionada!);
                        if (obs != null) {
                          if (obs.isNotEmpty) {
                            await vm.registrarEvento(obs);
                          }
                          await vm.registrarPago();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF90CAF9),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Registrar pago'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo de confirmación de pago
  Future<String?> _showConfirmDialog(
      BuildContext context, num monto, int cuota) async {
    String? obs;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'CONFIRMAR PAGO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '¿Registrar pago de la cuota $cuota por S/${monto.toStringAsFixed(2)}?',
                textAlign: TextAlign.justify,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: TextField(
                  minLines: 1,
                  maxLines: 5,
                  onChanged: (t) => obs = t.trim().isEmpty ? null : t.trim(),
                  decoration: InputDecoration(
                    hintText: 'Observaciones (opcional)',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true ? obs : null;
  }

  // Diálogo de historial completo
  void _showHistorialDialog(BuildContext context, HistorialRead h) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'HISTORIAL DE PAGO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Divider(thickness: 1),
              const SizedBox(height: 12),
              _buildHistRow(
                  label: 'Inicio:', value: _formatFecha(h.fechaInicio)),
              _buildHistRow(
                  label: 'Fin:', value: _formatFecha(h.fechaCierreReal)),
              _buildHistRow(
                  label: 'Monto solicitado:', value: 'S/${h.montoSolicitado}'),
              _buildHistRow(
                  label: 'Total pagado:', value: 'S/${h.totalPagado}'),
              _buildHistRow(label: 'Días totales:', value: '${h.diasTotales}'),
              _buildHistRow(
                  label: 'Días de atraso:', value: '${h.diasAtrasoMax}'),
              const SizedBox(height: 16),
              const Divider(thickness: 1),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF90CAF9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 6,
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return '-';
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
