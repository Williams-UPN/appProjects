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

  // fecha normalizada del primer pago
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

    final num diario = cliente!['cuota_diaria'] as num;
    final num ultima = cliente!['ultima_cuota'] as num;
    final int plazoDias = cliente!['plazo_dias'] as int;

    final bool esUltima = cuotaSeleccionada == plazoDias;
    final num montoAPagar = esUltima ? ultima : diario;

    try {
      await supabase.from('pagos').insert({
        'cliente_id': widget.clienteId,
        'numero_cuota': cuotaSeleccionada,
        'monto_pagado': montoAPagar,
      });

      // Luego recargamos para obtener el saldo actualizado
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmarYRegistrarPago() async {
    final num diario = cliente!['cuota_diaria'] as num;
    final num ultima = cliente!['ultima_cuota'] as num;
    final int plazoDias = cliente!['plazo_dias'] as int;
    final bool esUltima = cuotaSeleccionada == plazoDias;
    final num valorCuota = esUltima ? ultima : diario;

    String? obsIncidencia;

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1) Título en mayúsculas y centrado
              Text(
                'CONFIRMAR PAGO',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // 2) Texto justificiado
              Text(
                '¿Registrar pago de la cuota '
                '$cuotaSeleccionada \npor S/${valorCuota.toStringAsFixed(2)}?',
                textAlign: TextAlign.justify,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 150,
                ),
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
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(letterSpacing: 1),
                    ),
                  ),
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

  int get siguienteCuotaValida {
    if (cuotasPagadas.isEmpty) return 1;
    return cuotasPagadas.reduce((a, b) => a > b ? a : b) + 1;
  }

  String _estadoLabel(String raw, int diasAtraso) {
    // 1) Pago próximo
    if (raw == 'proximo') {
      return 'Pago próximo';
    }
    // 2) Completado
    if (raw == 'completo') {
      return 'Completado';
    }
    // 3) Atrasado
    if (raw == 'atrasado') {
      return '$diasAtraso ${diasAtraso == 1 ? 'día' : 'días'} de atraso';
    }
    // 4) Pendiente hoy
    if (raw == 'pendiente') {
      return 'Pago pendiente hoy';
    }
    // 5) Al día
    return 'Al día';
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
        return Colors.blue;
      case 'al_dia':
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
    final cuotaDiaria = cliente!['cuota_diaria'] as num;
    final saldoPendiente = cliente!['saldo_pendiente'] as num;
    final plazoDias = cliente!['plazo_dias'] as int;
    final estadoRaw = cliente!['estado_pago'] as String;
    final diasAtraso = cliente!['dias_atraso'] as int;

    // <<< LÓGICA PARA DISPLAY DE ÚLTIMA CUOTA >>>
    final hoy = DateTime.now();
    final today = DateTime(hoy.year, hoy.month, hoy.day);
    final ultimoVenc = primerPagoDate.add(Duration(days: plazoDias - 1));
    final esUltimoDia = today == ultimoVenc;
    final displayCuota = (esUltimoDia && saldoPendiente < cuotaDiaria)
        ? saldoPendiente
        : cuotaDiaria;
    // <<< FIN >>>

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
                  _InfoRow(
                    label: 'Cuota diaria:',
                    value: 'S/${displayCuota.toStringAsFixed(2)}',
                  ),
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
          bg = Colors.blue[100]!; // fondo azul suave
          border = Colors.blue; // borde azul
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
                              color: Colors.blue, // cambia a azul
                            ))
                    ],
                  ),
          ),
        );
      },
    );
  }
}
