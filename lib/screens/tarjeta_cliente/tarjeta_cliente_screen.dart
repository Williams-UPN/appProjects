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
    debugPrint('🔔 [UI] historiales.length = ${historiales.length}');
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
                        if (n <= siguienteCuotaValida) {
                          vm.selectCuota(n);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Primero paga la cuota $siguienteCuotaValida')),
                          );
                        }
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
                        onPressed: vm.puedeIniciarRefinanciamiento
                            ? () {
                                vm.iniciarRefinanciamiento();
                                _showRefinanciarDialog(context);
                              }
                            : null, // si no puede, queda deshabilitado
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Refinanciar'),
                      ),
                    ],
                  ),
                ),

                // Ver historial
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: TextButton.icon(
                    onPressed: historiales.isNotEmpty
                        ? () => _showHistorialDialog(context, historiales)
                        : null,
                    icon: const Icon(Icons.history, color: Colors.black54),
                    label: Text(
                      'Ver Historial del Cliente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: historiales.isNotEmpty
                            ? Colors.black87
                            : Colors.black38,
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
      BuildContext context, List<HistorialRead> historiales) async {
    final recientes = historiales.length <= 5
        ? historiales
        : historiales.sublist(historiales.length - 5);

    final pageController = PageController();
    int currentPage = 0;

    final maxHeight = MediaQuery.of(context).size.height * 0.5; // 50%
    final pageViewHeight = maxHeight * 0.6; // 60% del diálogo

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // insetPadding más grande para hacerlo más estrecho
        insetPadding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
            minWidth: MediaQuery.of(context).size.width * 0.7, // 70% ancho
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Título centrado
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Text(
                  'HISTORIAL DE CRÉDITOS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

              const Divider(height: 1),

              // PageView con altura fija
              SizedBox(
                height: pageViewHeight,
                child: PageView.builder(
                  controller: pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: recientes.length,
                  onPageChanged: (idx) => setState(() {
                    currentPage = idx;
                  }),
                  itemBuilder: (context, index) {
                    final h = recientes[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHistRow(
                              label: 'Inicio:',
                              value: _formatFecha(h.fechaInicio)),
                          _buildHistRow(
                              label: 'Fin:',
                              value: _formatFecha(h.fechaCierreReal)),
                          _buildHistRow(
                              label: 'Monto solicitado:',
                              value: 'S/${h.montoSolicitado}'),
                          _buildHistRow(
                              label: 'Total pagado:',
                              value: 'S/${h.totalPagado}'),
                          _buildHistRow(
                              label: 'Días totales:',
                              value: '${h.diasTotales}'),
                          _buildHistRow(
                              label: 'Días de atraso:',
                              value: '${h.diasAtrasoMax}'),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Dots de paginación
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(recientes.length, (i) {
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
                        width: isActive ? 14 : 10,
                        height: isActive ? 14 : 10,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isActive ? Colors.blueAccent : Colors.grey[300],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Botón Cerrar
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
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
                          color: Colors.black, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRefinanciarDialog(BuildContext context) async {
    final vm = context.read<TarjetaClienteViewModel>();
    vm.iniciarRefinanciamiento();

    // ① Capturamos el messenger de la pantalla **antes** de abrir el diálogo
    final messenger = ScaffoldMessenger.of(context);

    double montoNuevo = 0;
    int plazoOriginal = vm.plazoRefinanciar;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('Refinanciar Préstamo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1) Saldo pendiente actual
                  Row(
                    children: [
                      const Text('Saldo pendiente: '),
                      Text('S/${vm.saldoPendienteDisplay.toStringAsFixed(2)}'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2) Mostrar los nuevos montos (si hay montoAdicional)
                  if (vm.montoAdicional > 0) ...[
                    Row(
                      children: [
                        const Text('Nuevo monto prestado: '),
                        Text(
                            'S/${vm.nuevoMontoPrestadoDisplay.toStringAsFixed(2)}'),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Nuevo saldo pendiente: '),
                        Text(
                            'S/${vm.nuevoSaldoPendienteDisplay.toStringAsFixed(2)}'),
                      ],
                    ),
                    Row(
                      children: [
                        const Text('Nueva cuota diaria: '),
                        Text(
                            'S/${vm.nuevaCuotaDiariaDisplay.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3) Plazo (fijo, deshabilitado)
                  InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Plazo (días)'),
                    child: Text('$plazoOriginal días'),
                  ),

                  const SizedBox(height: 12),

                  // 4) Monto a solicitar
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Monto a solicitar',
                      prefixText: 'S/ ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      montoNuevo = double.tryParse(v) ?? 0;
                      vm.setMontoAdicional(montoNuevo);
                      setState(() {}); // fuerza rebuild del diálogo
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: montoNuevo > 0
                      ? () async {
                          // ② Cerramos el diálogo con su propio context
                          Navigator.of(dialogContext).pop();
                          // ③ Esperamos el refinanciamiento
                          final ok = await vm.confirmarRefinanciamiento(
                            montoNuevo,
                            plazoOriginal,
                          );
                          // ④ Mostramos el SnackBar con el messenger capturado
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Refinanciamiento exitoso'
                                    : 'Error al refinanciar',
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
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
