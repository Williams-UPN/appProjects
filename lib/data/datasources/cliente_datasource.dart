import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/cliente_read.dart';
import '../../models/cliente_detail_read.dart';
import '../../models/pago_read.dart';
import '../../models/cronograma_read.dart';
import '../../models/historial_read.dart';

abstract class ClienteDatasource {
  Future<List<ClienteRead>> fetchClientes({int page = 0, int size = 20});
  Future<List<ClienteRead>> searchClientes({
    required String term,
    int page = 0,
    int size = 20,
  });
  Future<List<ClienteRead>> fetchClientesPendientes({
    int page = 0,
    int size = 20,
  });
  Future<ClienteDetailRead> fetchClienteById(int id);
  Future<List<PagoRead>> fetchPagos(int clienteId);
  Future<List<CronogramaRead>> fetchCronograma(int clienteId);
  Future<List<HistorialRead>> fetchHistoriales(int clienteId);
  Future<bool> registrarPago(int clienteId, int numeroCuota, num monto);
  Future<bool> registrarEvento(int clienteId, String descripcion);
}

class SupabaseClienteDatasource implements ClienteDatasource {
  final SupabaseClient _supabase;
  SupabaseClienteDatasource(this._supabase);

  @override
  Future<List<ClienteRead>> fetchClientes({
    int page = 0,
    int size = 20,
  }) async {
    final from = page * size, to = from + size - 1;
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select(
          'id, nombre, telefono, direccion, negocio, '
          'estado_real, dias_reales, score_actual, has_history',
        )
        .order('id', ascending: true)
        .range(from, to);
    return (raw as List)
        .map((m) => ClienteRead.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ClienteRead>> searchClientes({
    required String term,
    int page = 0,
    int size = 20,
  }) async {
    final filter = '%${term.toLowerCase()}%';
    final from = page * size, to = from + size - 1;
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select(
          'id, nombre, telefono, direccion, negocio, '
          'estado_real, dias_reales, score_actual, has_history',
        )
        .or('nombre.ilike.$filter,telefono.ilike.$filter,negocio.ilike.$filter')
        .order('id', ascending: true)
        .range(from, to);
    return (raw as List)
        .map((m) => ClienteRead.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ClienteRead>> fetchClientesPendientes({
    int page = 0,
    int size = 20,
  }) async {
    final from = page * size, to = from + size - 1;
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select(
          'id, nombre, telefono, direccion, negocio, '
          'estado_real, dias_reales, score_actual, has_history',
        )
        .gt('dias_reales', 0)
        .order('dias_reales', ascending: true)
        .order('id', ascending: true)
        .range(from, to);
    return (raw as List)
        .map((m) => ClienteRead.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ClienteDetailRead> fetchClienteById(int id) async {
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select(
          'id, nombre, telefono, direccion, negocio, '
          'estado_real, dias_reales, score_actual, has_history, '
          'monto_solicitado, fecha_primer_pago, cuota_diaria, '
          'ultima_cuota, plazo_dias, saldo_pendiente',
        )
        .eq('id', id)
        .single();
    return ClienteDetailRead.fromMap(raw);
  }

  @override
  Future<List<PagoRead>> fetchPagos(int clienteId) async {
    final raw = await _supabase
        .from('pagos')
        .select('numero_cuota')
        .eq('cliente_id', clienteId);
    return (raw as List)
        .map((e) => PagoRead.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CronogramaRead>> fetchCronograma(int clienteId) async {
    final raw = await _supabase
        .from('cronograma')
        .select('numero_cuota, monto_cuota, fecha_pagado')
        .eq('cliente_id', clienteId)
        .order('numero_cuota');
    return (raw as List)
        .map((e) => CronogramaRead.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<HistorialRead>> fetchHistoriales(int clienteId) async {
    final raw = await _supabase
        .from('v_creditos_cerrados')
        .select('fecha_inicio, '
            'fecha_cierre_real, '
            'monto_solicitado, '
            'total_pagado, '
            'dias_totales, '
            'dias_atraso_max')
        .eq('credito_id', clienteId)
        .order('fecha_cierre_real', ascending: true);

    return (raw as List)
        .map((m) => HistorialRead.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> registrarPago(int clienteId, int numeroCuota, num monto) async {
    debugPrint('🔔 [DS] Supabase insert pagos -> '
        '{cliente_id: $clienteId, numero_cuota: $numeroCuota, monto_pagado: $monto}');
    try {
      await _supabase.from('pagos').insert({
        'cliente_id': clienteId,
        'numero_cuota': numeroCuota,
        'monto_pagado': monto,
      });
      return true;
    } catch (e) {
      debugPrint('🔴 [DS] Error registrarPago: $e');
      return false;
    }
  }

  @override
  Future<bool> registrarEvento(int clienteId, String descripcion) async {
    try {
      await _supabase.from('historial_eventos').insert({
        'cliente_id': clienteId,
        'descripcion': descripcion,
      });
      return true;
    } catch (e) {
      debugPrint('🔴 [DS] Error registrarEvento: $e');
      return false;
    }
  }
}
