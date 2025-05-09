import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TarjetaClienteScreen extends StatefulWidget {
  final int clienteId;
  const TarjetaClienteScreen({super.key, required this.clienteId});

  @override
  State<TarjetaClienteScreen> createState() => _TarjetaClienteScreenState();
}

class _TarjetaClienteScreenState extends State<TarjetaClienteScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? cliente;
  Map<String, dynamic>? historialCerrado;
  List<Map<String, dynamic>> cronograma = [];
  List<int> cuotasPagadas = [];
  int? cuotaSeleccionada;
  bool _isLoading = true;
  late DateTime primerPagoDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // Disparo paralelo sin <…> en los select:
      final Future cFuture = supabase
          .from('v_clientes_con_estado')
          .select('*')
          .eq('id', widget.clienteId)
          .single();

      final Future pFuture = supabase
          .from('pagos')
          .select('numero_cuota')
          .eq('cliente_id', widget.clienteId);

      final Future crFuture = supabase
          .from('cronograma')
          .select('numero_cuota, monto_cuota, fecha_pagado')
          .eq('cliente_id', widget.clienteId)
          .order('numero_cuota');

      final Future histFuture = supabase
          .from('v_cliente_historial_completo')
          .select('fecha_inicio,fecha_cierre_real,monto_solicitado,'
              'total_pagado,dias_totales,dias_atraso_max')
          .eq('cliente_id', widget.clienteId)
          .maybeSingle();

      // Espero las 4 al mismo tiempo
      final results =
          await Future.wait([cFuture, pFuture, crFuture, histFuture]);

      // Casteo cada uno:
      final Map<String, dynamic> c =
          (results[0] as Map).cast<String, dynamic>();
      final List<Map<String, dynamic>> p = (results[1] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final List<Map<String, dynamic>> cron = (results[2] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final Map<String, dynamic>? hist = results[3] == null
          ? null
          : (results[3] as Map).cast<String, dynamic>();

      // Normaliza la fecha de primer pago
      final rawPrimer = DateTime.parse(c['fecha_primer_pago'] as String);
      final primer = DateTime(rawPrimer.year, rawPrimer.month, rawPrimer.day);

      // Un solo setState
      setState(() {
        cliente = c;
        cuotasPagadas = p.map((e) => e['numero_cuota'] as int).toList();
        cronograma = cron;
        historialCerrado = hist;
        primerPagoDate = primer;
        cuotaSeleccionada = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
      Navigator.pop(context);
    }
  }

  Future<void> _registrarPago() async {
    if (cuotaSeleccionada == null) return;

    final diario = cliente!['cuota_diaria'] as num;
    final ultima = cliente!['ultima_cuota'] as num;
    final plazoDias = cliente!['plazo_dias'] as int;
    final esUltima = cuotaSeleccionada == plazoDias;
    final montoAPagar = esUltima ? ultima : diario;

    try {
      await supabase.from('pagos').insert({
        'cliente_id': widget.clienteId,
        'numero_cuota': cuotaSeleccionada,
        'monto_pagado': montoAPagar,
      });
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmarYRegistrarPago() async {
    final diario = cliente!['cuota_diaria'] as num;
    final ultima = cliente!['ultima_cuota'] as num;
    final plazoDias = cliente!['plazo_dias'] as int;
    final esUltima = cuotaSeleccionada == plazoDias;
    final valorCuota = esUltima ? ultima : diario;

    String? obsIncidencia;
    final confirmado = await showDialog<bool>(
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
              const Text('CONFIRMAR PAGO',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(
                '¿Registrar pago de la cuota $cuotaSeleccionada \npor S/${valorCuota.toStringAsFixed(2)}?',
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
                      obsIncidencia = t.trim().isEmpty ? null : t.trim(),
                  decoration: InputDecoration(
                    hintText: 'Observaciones (opcional)',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
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

    if (confirmado == true) {
      if (obsIncidencia != null) {
        await supabase.from('historial_eventos').insert({
          'cliente_id': widget.clienteId,
          'descripcion': obsIncidencia,
        });
      }
      await _registrarPago();
    }
  }

  void _mostrarHistorial() {
    final h = historialCerrado!;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.white, // fondo blanco
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ——— título ———
              const Text(
                'HISTORIAL DE PAGO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Divider(thickness: 1), // línea divisoria
              const SizedBox(height: 12),

              // ——— contenido alineado ———
              _buildHistRow(
                  label: 'Inicio:', value: _formatFecha(h['fecha_inicio'])),
              _buildHistRow(
                  label: 'Fin:', value: _formatFecha(h['fecha_cierre_real'])),
              _buildHistRow(
                  label: 'Monto solicitado:',
                  value: 'S/${h['monto_solicitado']}'),
              _buildHistRow(
                  label: 'Total pagado:', value: 'S/${h['total_pagado']}'),
              _buildHistRow(
                  label: 'Días totales:', value: '${h['dias_totales']}'),
              _buildHistRow(
                  label: 'Días de atraso:', value: '${h['dias_atraso_max']}'),

              const SizedBox(height: 16),
              const Divider(thickness: 1),
              const SizedBox(height: 16),

              // ——— botón Cerrar ———
              SizedBox(
                height: 40,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF90CAF9), // tu azul claro
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(
                      color: Colors.black, // texto negro
                      fontWeight: FontWeight.w600,
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

  /// Fila interna para alinear etiqueta + valor
  Widget _buildHistRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
              softWrap: false, // no hace salto
              maxLines: 1, // sólo una línea
              overflow: TextOverflow.visible, // deja que se vea todo
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFecha(dynamic fecha) {
    if (fecha == null) return '-';
    final dt = DateTime.parse(fecha.toString());
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year}';
  }

  int get siguienteCuotaValida {
    if (cuotasPagadas.isEmpty) return 1;
    return cuotasPagadas.reduce((a, b) => a > b ? a : b) + 1;
  }

  String _estadoLabel(String raw, int diasAtraso) {
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

  Color _estadoColor(String raw) {
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading || cliente == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = cliente!['nombre'] as String;
    final negocio = cliente!['negocio'] as String?;
    final montoSolicitado = cliente!['monto_solicitado'] as num;
    final saldoPendiente = cliente!['saldo_pendiente'] as num;
    final plazoDias = cliente!['plazo_dias'] as int;
    final estadoRaw = cliente!['estado_real'] as String;
    final diasAtraso = cliente!['dias_reales'] as int;

    // Calcular cuota a mostrar
    final cuotaData = cronograma.firstWhere(
      (r) => r['numero_cuota'] == cuotaSeleccionada,
      orElse: () => {'monto_cuota': cliente!['cuota_diaria']},
    );
    final num displayCuota = cuotaData['monto_cuota'] as num;
    final label = _estadoLabel(estadoRaw, diasAtraso);
    final color = _estadoColor(estadoRaw);

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
            Text(nombre,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if ((negocio ?? '').isNotEmpty)
              Text(negocio!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Monto prestado:',
                    value: 'S/$montoSolicitado',
                    color: Colors.green,
                  ),
                  _InfoRow(
                    label: 'Saldo pendiente:',
                    value: 'S/${saldoPendiente.toStringAsFixed(2)}',
                    color: Colors.red,
                  ),
                  _InfoRow(
                    label: 'Cuota diaria:',
                    value: 'S/${displayCuota.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.justify,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CuotasGrid(
                dias: plazoDias,
                cuotasPagadas: cuotasPagadas,
                cuotaSeleccionada: cuotaSeleccionada,
                siguienteCuotaValida: siguienteCuotaValida,
                fechaInicio: primerPagoDate,
                onSeleccionar: (n) {
                  if (n != siguienteCuotaValida) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Debes pagar la cuota anterior para continuar'),
                          duration: Duration(milliseconds: 800)),
                    );
                    return;
                  }
                  setState(() => cuotaSeleccionada = n);
                },
              ),
            ),
            // ——— Ver Historial ———
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: GestureDetector(
                // Solo invoca _mostrarHistorial si está COMPLETO
                onTap: cliente!['estado_pago'] == 'completo'
                    ? _mostrarHistorial
                    : null,
                child: Opacity(
                  // Atenúa al 50% cuando NO está completo
                  opacity: cliente!['estado_pago'] == 'completo' ? 1.0 : 0.5,
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cuotaSeleccionada == siguienteCuotaValida
                    ? _confirmarYRegistrarPago
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
}

/// Recuadro informativo para etiqueta + valor
class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _InfoRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value,
              style: TextStyle(fontSize: 16, color: color ?? Colors.black)),
        ],
      ),
    );
  }
}

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
            fechaInicio.year, fechaInicio.month, fechaInicio.day + idx);

        final estaPag = cuotasPagadas.contains(numCuota);
        final sel = cuotaSeleccionada == numCuota;
        final esHoy = dueDate == today;
        final esProx = numCuota == 1 && fechaInicio.isAfter(today) && !estaPag;
        final vencida = dueDate.isBefore(today) && !estaPag;

        Color bg, border;
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
                        const Text('HOY',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w500)),
                      if (esProx)
                        const Text('PRÓXIMO',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
