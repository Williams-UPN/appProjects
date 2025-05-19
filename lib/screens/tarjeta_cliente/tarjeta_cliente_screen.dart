// lib/screens/tarjeta_cliente/tarjeta_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/cliente_detail_read.dart';
import '../../models/historial_read.dart';
import '../../viewmodels/tarjeta_cliente_viewmodel.dart';
import '../../widgets/info_row.dart';
import '../../widgets/cuotas_grid.dart';

const blue = Color(0xFF90CAF9);

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

  Future<void> _onRegistrarPago() async {
    final vm = context.read<TarjetaClienteViewModel>();
    final monto = vm.cuotaSeleccionada == vm.cliente!.plazoDias
        ? vm.cliente!.ultimaCuota
        : vm.cliente!.cuotaDiaria;
    final cuota = vm.cuotaSeleccionada!;
    // 1) Abre diálogo de confirmación
    final ok = await _showConfirmDialog(context, monto, cuota);
    if (!ok) return; // si el usuario canceló, salimos
    debugPrint('🔔 [UI] Usuario confirmó pago de cuota $cuota');

    // 2) Registra el pago
    final success = await vm.registrarPago(observaciones: _lastObservaciones);
    debugPrint('🔔 [UI] registrarPago() devolvió: $success');

    // 3) Muestra un SnackBar de resultado
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Pago de cuota $cuota registrado'
              : 'Error al registrar pago'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TarjetaClienteViewModel>();

    // ─────────────────────────────────────────────────────
    // 0) Lógica del botón inferior: Registrar pago o Nuevo crédito
    final esCompleto = vm.isCreditComplete;
    final textoBoton = esCompleto ? 'Nuevo crédito' : 'Registrar pago';
    final accionBoton = esCompleto
        ? () {
            debugPrint('🔔 [UI] Botón “Nuevo crédito” pulsado');
            _vm.iniciarNuevoCredito();
            _showNuevoCreditoDialog(context);
          }
        : () {
            debugPrint('🔔 [UI] Botón “Registrar pago” pulsado');
            _onRegistrarPago(); // <-- aquí llamamos a tu nuevo flujo
          };

    // ─────────────────────────────────────────────────────
    // 1) Guard: mientras carga o no hay cliente
    if (vm.isLoading || vm.cliente == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ─────────────────────────────────────────────────────
    // 2) Datos necesarios para la UI
    final ClienteDetailRead c = vm.cliente!;
    final pagos = vm.pagos.map((p) => p.numeroCuota).toList();
    final cronograma = vm.cronograma;
    final historiales = vm.historiales;
    debugPrint('🔔 [UI] historiales.length = ${historiales.length}');
    final cuotaSeleccionada = vm.cuotaSeleccionada;
    final siguienteCuotaValida =
        pagos.isEmpty ? 1 : pagos.reduce((a, b) => a > b ? a : b) + 1;

    // ─────────────────────────────────────────────────────
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
            // ─────────────────────────────────────────────────────
            // 1) Zona superior
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
            // 2) Zona media: Cronograma
            vm.showCuotasGrid
                ? Expanded(
                    child: CuotasGrid(
                      dias: c.plazoDias,
                      cronograma: cronograma,
                      cuotaSeleccionada: cuotaSeleccionada,
                      siguienteCuotaValida: siguienteCuotaValida,
                      fechaInicio: c.fechaPrimerPago,
                      onSeleccionar: (n) {
                        debugPrint(
                            '▷ cuota tocada: $n, siguiente válida: $siguienteCuotaValida');
                        if (n <= siguienteCuotaValida) {
                          vm.selectCuota(n);
                          debugPrint(
                              '▷ cuotaSeleccionada ahora es ${vm.cuotaSeleccionada}');
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Primero paga la cuota $siguienteCuotaValida',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  )
                : const SizedBox.shrink(),

            // ─────────────────────────────────────────────────────
            // 3) Zona inferior: Controles anclados al fondo
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          iconColor: blue,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          if (vm.cliente != null) {
                            _abrirMapa(
                                vm.cliente!.latitud, vm.cliente!.longitud);
                          }
                        },
                        icon: const Icon(Icons.location_on, size: 20),
                        label: const Text('Ubicación'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          iconColor: blue,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: vm.puedeIniciarRefinanciamiento
                            ? () {
                                vm.iniciarRefinanciamiento();
                                _showRefinanciarDialog(context);
                              }
                            : null,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Refinanciar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.black,
                          iconColor: blue,
                        ),
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
                    icon: Icon(
                      Icons.history,
                      color: historiales.isNotEmpty
                          ? Colors.black54
                          : Colors.black38,
                    ),
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

                // ─────────────────────────────────────────────────────
                // Registrar pago / Nuevo crédito
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: accionBoton,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(textoBoton),
                  ),
                ),
                const SizedBox(height: 20),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: blue, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CONFIRMAR PAGO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black, // texto en negro
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '¿Registrar pago de la cuota $cuota por S/${monto.toStringAsFixed(2)}?',
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black, // texto en negro
                ),
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
                    // ignore: deprecated_member_use
                    hintStyle: TextStyle(color: Colors.black.withOpacity(0.6)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: blue),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: blue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: blue, width: 2),
                    ),
                  ),
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      'Confirmar',
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
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

  Future<void> _showNuevoCreditoDialog(BuildContext context) async {
    final vm = context.read<TarjetaClienteViewModel>();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          // ——— 1) Calculamos flags antes de construir los widgets ———
          final montoValido = vm.nuevoMontoSolicitado > 0;
          final fechaValida = vm.nuevaFechaPrimerPago != null;
          // (Si necesitas validar plazo: final plazoValido = vm.nuevoPlazo > 0;)

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: blue, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'NUEVO CRÉDITO',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // 1) Monto
                  TextFormField(
                    decoration:
                        const InputDecoration(labelText: 'Monto solicitado'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      vm.setNuevoMonto(double.tryParse(v) ?? 0);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2) Plazo
                  DropdownButtonFormField<int>(
                    value: vm.nuevoPlazo,
                    decoration:
                        const InputDecoration(labelText: 'Plazo (días)'),
                    items: [12, 24]
                        .map((d) =>
                            DropdownMenuItem(value: d, child: Text('$d días')))
                        .toList(),
                    onChanged: (d) {
                      vm.setNuevoPlazo(d!);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),

                  // 3) Fecha primer pago
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Fecha primer pago:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(
                          vm.nuevaFechaPrimerPago == null
                              ? '-'
                              : '${vm.nuevaFechaPrimerPago!.day.toString().padLeft(2, '0')}/'
                                  '${vm.nuevaFechaPrimerPago!.month.toString().padLeft(2, '0')}/'
                                  '${vm.nuevaFechaPrimerPago!.year}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await vm.pickNuevaFechaPrimerPago(ctx);
                          setState(() {});
                        },
                        child: const Text('Seleccionar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4) Preview de totales (solo si monto y fecha válidos)
                  if (montoValido && fechaValida) ...[
                    _buildPreviewRow(
                      'Total a pagar:',
                      'S/${vm.nuevoTotalPagar.toStringAsFixed(2)}',
                    ),
                    _buildPreviewRow(
                      'Cuota diaria:',
                      'S/${vm.nuevaCuotaDiaria.toStringAsFixed(2)}',
                    ),
                    if (vm.nuevaUltimaCuota != vm.nuevaCuotaDiaria)
                      _buildPreviewRow(
                        'Última cuota:',
                        'S/${vm.nuevaUltimaCuota.toStringAsFixed(2)}',
                      ),
                    const SizedBox(height: 16),
                  ],

                  // 5) Botones de acción
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: montoValido && fechaValida
                            ? () async {
                                debugPrint(
                                    '🔔 [UI] Botón Confirmar Nuevo Crédito pulsado');
                                Navigator.pop(ctx);

                                debugPrint(
                                    '🔔 [UI] Llamando vm.confirmarNuevoCredito()...');
                                final ok = await vm.confirmarNuevoCredito();

                                debugPrint(
                                    '🔔 [UI] confirmarNuevoCredito() devolvió: $ok');
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Crédito creado'
                                        : 'Error al crear crédito'),
                                  ),
                                );
                              }
                            : null,
                        // resto del estilo…
                        child: const Text('Confirmar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w500))),
        Expanded(flex: 6, child: Text(value, textAlign: TextAlign.right)),
      ]),
    );
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
    final messenger = ScaffoldMessenger.of(context);

    double montoNuevo = 0;
    int plazoOriginal = vm.plazoRefinanciar;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFF90CAF9), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // — Título —
                    const Center(
                      child: Text(
                        'REFINANCIAR PRÉSTAMO',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // — Saldo pendiente —
                    Row(
                      children: [
                        const Text('Saldo pendiente: ',
                            style: TextStyle(color: Colors.black)),
                        Text(
                          'S/${vm.saldoPendienteDisplay.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // — Resultados intermedios —
                    if (vm.montoAdicional > 0) ...[
                      Row(
                        children: [
                          const Text('Nuevo monto prestado: ',
                              style: TextStyle(color: Colors.black)),
                          Text(
                            'S/${vm.nuevoMontoPrestadoDisplay.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Nuevo saldo pendiente: ',
                              style: TextStyle(color: Colors.black)),
                          Text(
                            'S/${vm.nuevoSaldoPendienteDisplay.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('Nueva cuota diaria: ',
                              style: TextStyle(color: Colors.black)),
                          Text(
                            'S/${vm.nuevaCuotaDiariaDisplay.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ],
                      ),
                      if (vm.nuevaUltimaCuotaDisplay !=
                          vm.nuevaCuotaDiariaDisplay)
                        Row(
                          children: [
                            const Text('Nueva última cuota: ',
                                style: TextStyle(color: Colors.black)),
                            Text(
                              'S/${vm.nuevaUltimaCuotaDisplay.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],

                    // — Plazo —
                    InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Plazo (días)'),
                      child: Text(
                        '$plazoOriginal días',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // — Campo monto adicional —
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Monto a solicitar',
                        prefixText: 'S/ ',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        montoNuevo = double.tryParse(v) ?? 0;
                        vm.setMontoAdicional(montoNuevo);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 24),

                    // — Botones de acción —
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: montoNuevo > 0
                              ? () async {
                                  Navigator.of(dialogContext).pop();
                                  final ok = await vm.confirmarRefinanciamiento(
                                      montoNuevo, plazoOriginal);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Refinanciamiento exitoso'
                                          : 'Error al refinanciar'),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF90CAF9),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Confirmar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

  Future<void> _abrirMapa(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ubicación no disponible para este cliente.')),
        );
      }
      return;
    }

    final Uri googleMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query= ($lat,$lng)');
    final Uri wazeUri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');

    final bool puedeAbrirGoogleMaps = await canLaunchUrl(googleMapsUri);
    final bool puedeAbrirWaze = await canLaunchUrl(wazeUri);

    List<Widget> opcionesMapa = [];

    if (puedeAbrirGoogleMaps) {
      opcionesMapa.add(
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context); // Cierra el diálogo
            launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
          },
          child: const Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.map_sharp, color: Colors.blue),
              ),
              Text('Google Maps'),
            ],
          ),
        ),
      );
    }

    if (puedeAbrirWaze) {
      opcionesMapa.add(
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context); // Cierra el diálogo
            launchUrl(wazeUri, mode: LaunchMode.externalApplication);
          },
          child: const Row(
            children: [
              Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Icon(Icons.directions_car,
                    color: Colors.lightBlueAccent), // Icono genérico para Waze
              ),
              Text('Waze'),
            ],
          ),
        ),
      );
    }

    if (opcionesMapa.isEmpty) {
      final Uri geoUri =
          Uri.parse('geo:$lat,$lng?q=$lat,$lng(Ubicación del Cliente)');
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('No hay aplicaciones de mapas instaladas.')),
          );
        }
      }
      return;
    }

    if (opcionesMapa.length == 1) {
      if (puedeAbrirGoogleMaps) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else if (puedeAbrirWaze) {
        await launchUrl(wazeUri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text('Abrir ubicación con:'),
              children: opcionesMapa,
            );
          },
        );
      }
    }
  }
}
