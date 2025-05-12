// lib/screens/tarjeta_cliente/tarjeta_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/cliente_detail_read.dart';
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
  String? _lastObservaciones;

  @override
  void initState() {
    super.initState();
    _vm = context.read<TarjetaClienteViewModel>();
    _vm.loadData(widget.clienteId);
  }

  Future<void> _llamar(String numero) async {
    final uri = Uri(scheme: 'tel', path: numero);
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('📱 Simulando llamada a $numero')),
      );
    }
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
    final historiales = vm.historiales;
    final cuotaSeleccionada = vm.cuotaSeleccionada;
    final siguienteCuotaValida =
        pagos.isEmpty ? 1 : pagos.reduce((a, b) => a > b ? a : b) + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Cliente'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      // dentro de tu Scaffold:
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────
            // 1) Zona superior: nombre + tarjeta de datos
            Text(
              c.nombre,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (c.negocio.isNotEmpty)
              Text(c.negocio, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
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
                    value: 'S/${vm.montoPrestadoDisplay.toStringAsFixed(2)}',
                    color: Colors.green,
                  ),
                  InfoRow(
                    label: 'Saldo pendiente:',
                    value: 'S/${vm.saldoPendienteDisplay.toStringAsFixed(2)}',
                    color: Colors.red,
                  ),
                  InfoRow(
                    label: 'Cuota diaria:',
                    value: 'S/${vm.cuotaDiariaDisplay.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    vm.estadoLabel,
                    textAlign: TextAlign.justify,
                    style: TextStyle(
                      color: vm.estadoColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ─────────────────────────────────────────────────────
            // 2) Zona media: grid ocupa todo el espacio restante
            vm.showCuotasGrid
                ? Expanded(
                    child: CuotasGrid(
                      dias: c.plazoDias,
                      cronograma: cronograma,
                      cuotaSeleccionada: cuotaSeleccionada,
                      siguienteCuotaValida: siguienteCuotaValida,
                      fechaInicio: c.fechaPrimerPago,
                      onSeleccionar: (n) {
                        vm.selectCuota(n);
                      },
                    ),
                  )
                : const SizedBox.shrink(),

            // ─────────────────────────────────────────────────────
            // 3) Zona inferior: controles anclados abajo
            //    envolvemos todo en un Column para poder tener separación
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Llamar / Ubicación / Refinanciar
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => _llamar(c.telefono),
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
                    onTap: vm.isCreditComplete && historiales.isNotEmpty
                        ? () => _showHistorialDialog(context, historiales)
                        : null,
                    child: Opacity(
                      opacity: vm.isCreditComplete ? 1.0 : 0.5,
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

                // Registrar pago / Nuevo crédito
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: vm.botonAction == null
                        ? null
                        : () async {
                            debugPrint(
                                '🔔 [UI] Botón “${vm.botonLabel}” pulsado');
                            if (!vm.isCreditComplete) {
                              final confirmed = await _showConfirmDialog(
                                context,
                                vm.cuotaDiariaDisplay,
                                vm.cuotaSeleccionada!,
                              );
                              if (confirmed != true) return;
                              if (_lastObservaciones?.isNotEmpty == true) {
                                await vm.registrarEvento(_lastObservaciones!);
                              }
                            }
                            vm.botonAction!();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF90CAF9),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(vm.botonLabel),
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(
      BuildContext context, num monto, int cuota) async {
    String? obsLocal;
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
                  onChanged: (t) =>
                      obsLocal = t.trim().isEmpty ? null : t.trim(),
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
                      child: const Text('Cancelar')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirmar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      _lastObservaciones = obsLocal;
      return true;
    }
    return false;
  }

  void _showHistorialDialog(
      BuildContext context, List<HistorialRead> historiales) {
    // Controller para el PageView y estado interno para el dot activo
    final pageController = PageController();
    int currentPage = 0;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
                minWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // — Título —
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'HISTORIAL DE CRÉDITOS',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const Divider(thickness: 1),

                  // — PageView —
                  Expanded(
                    child: PageView.builder(
                      controller: pageController,
                      scrollDirection: Axis.vertical,
                      itemCount: historiales.length,
                      onPageChanged: (idx) => setState(() {
                        currentPage = idx;
                      }),
                      itemBuilder: (context, index) {
                        final h = historiales[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHistRow(
                                label: 'Inicio:',
                                value: _formatFecha(h.fechaInicio),
                              ),
                              _buildHistRow(
                                label: 'Fin:',
                                value: _formatFecha(h.fechaCierreReal),
                              ),
                              _buildHistRow(
                                label: 'Monto solicitado:',
                                value: 'S/${h.montoSolicitado}',
                              ),
                              _buildHistRow(
                                label: 'Total pagado:',
                                value: 'S/${h.totalPagado}',
                              ),
                              _buildHistRow(
                                label: 'Días totales:',
                                value: '${h.diasTotales}',
                              ),
                              _buildHistRow(
                                label: 'Días de atraso:',
                                value: '${h.diasAtrasoMax}',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(thickness: 1),

                  // — Dots de paginación clicables —
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(historiales.length, (i) {
                        final isActive = i == currentPage;
                        return GestureDetector(
                          onTap: () {
                            pageController.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                            setState(() {
                              currentPage = i;
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              width: isActive ? 12 : 8,
                              height: isActive ? 12 : 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? Colors.blueAccent
                                    : Colors.grey[300],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // — Botón Cerrar siempre visible —
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: const Color(0xFF90CAF9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // antes 6
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14)), // sube un poco la fuente si quieres
          ),
          Expanded(
            flex: 6,
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontWeight: FontWeight.w400, fontSize: 14)),
          )
        ],
      ),
    );
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return '-';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }
}
