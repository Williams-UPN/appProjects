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
  List<int> cuotasPagadas = [];
  int? cuotaSeleccionada;
  bool _isLoading = true;

  // guardamos la fecha normalizada del primer pago
  late DateTime primerPagoDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final c = await supabase
          .from('clientes')
          .select('*')
          .eq('id', widget.clienteId)
          .single();
      final p = await supabase
          .from('pagos')
          .select('numero_cuota')
          .eq('cliente_id', widget.clienteId);

      final cuotas =
          (p as List).map<int>((e) => e['numero_cuota'] as int).toList();

      final rawPrimer = DateTime.parse(c['fecha_primer_pago'] as String);
      primerPagoDate = DateTime(rawPrimer.year, rawPrimer.month, rawPrimer.day);

      setState(() {
        cliente = c;
        cuotasPagadas = cuotas;
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
    final num diario = cliente!['cuota_diaria'];
    final num saldo = cliente!['saldo_pendiente'];
    final num monto = saldo < diario ? saldo : diario;

    try {
      await supabase.from('pagos').insert({
        'cliente_id': widget.clienteId,
        'numero_cuota': cuotaSeleccionada,
        'monto_pagado': monto,
      });
      await supabase.from('clientes').update(
          {'ultima_cuota': cuotaSeleccionada}).eq('id', widget.clienteId);

      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmarYRegistrarPago() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Confirmar pago',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Deseas registrar el pago de la cuota $cuotaSeleccionada '
          'por S/${cliente!['cuota_diaria']}?',
          style: const TextStyle(color: Colors.black),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBBDEFB),
              foregroundColor: Colors.black,
              elevation: 6,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _registrarPago();
    }
  }

  int get siguienteCuotaValida {
    if (cuotasPagadas.isEmpty) return 1;
    return cuotasPagadas.reduce((a, b) => a > b ? a : b) + 1;
  }

  String _estadoLabel(String raw, int diasAtraso) {
    final hoy = DateTime.now();
    final today = DateTime(hoy.year, hoy.month, hoy.day);
    if (raw == 'al_dia' && primerPagoDate.isAfter(today)) {
      return 'Pago próximo';
    }
    switch (raw) {
      case 'pendiente':
        return 'Pago pendiente hoy';
      case 'atrasado':
        return '$diasAtraso ${diasAtraso == 1 ? 'día' : 'días'} de atraso';
      case 'al_dia':
        return 'Al día';
      case 'completo':
        return 'Completado';
      default:
        return raw;
    }
  }

  Color _estadoColor(String raw) {
    final hoy = DateTime.now();
    final today = DateTime(hoy.year, hoy.month, hoy.day);
    if (raw == 'al_dia' && primerPagoDate.isAfter(today)) {
      return Colors.green;
    }
    switch (raw) {
      case 'pendiente':
        return Colors.orange;
      case 'atrasado':
        return Colors.red;
      case 'al_dia':
        return Colors.green;
      case 'completo':
        return Colors.blue;
      default:
        return Colors.black;
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
    final cuotaDiaria = cliente!['cuota_diaria'] as num;
    final saldoPendiente = cliente!['saldo_pendiente'] as num;
    final plazoDias = cliente!['plazo_dias'] as int;
    final estadoRaw = cliente!['estado_pago'] as String;
    final diasAtraso = cliente!['dias_atraso'] as int;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                      label: 'Monto prestado:',
                      value: 'S/$montoSolicitado',
                      color: Colors.green),
                  _InfoRow(
                      label: 'Saldo pendiente:',
                      value: 'S/${saldoPendiente.toStringAsFixed(2)}',
                      color: Colors.red),
                  _InfoRow(label: 'Cuota diaria:', value: 'S/$cuotaDiaria'),
                  const SizedBox(height: 6),
                  Text(label,
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: cuotaSeleccionada == siguienteCuotaValida
                    ? _confirmarYRegistrarPago
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF90CAF9),
                  foregroundColor: Colors.black,
                  elevation: 6,
                  shadowColor: Colors.black26,
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
      itemBuilder: (ctx, idx) {
        final numCuota = idx + 1;
        final rawDue = fechaInicio.add(Duration(days: idx));
        final dueDate = DateTime(rawDue.year, rawDue.month, rawDue.day);

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
          bg = Colors.green[100]!;
          border = Colors.green;
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
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFFA726)))
                      else if (esProx)
                        const Text('PRÓXIMO',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.green)),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
