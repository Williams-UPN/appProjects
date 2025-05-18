// lib/data/datasources/cliente_datasource.dart

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

  Future<bool> nuevoCreditoRpc({
    required int clienteId,
    required double montoSolicitado,
    required int plazoDias,
    required String fechaPrimerPago, // formato "YYYY-MM-DD"
  });
}

class SupabaseClienteDatasource implements ClienteDatasource {
  final SupabaseClient _supabase;

  SupabaseClienteDatasource(this._supabase) {
    debugPrint('🔌 [DS] SupabaseClienteDatasource inicializado');
  }

  @override
  Future<List<ClienteRead>> fetchClientes({
    int page = 0,
    int size = 20,
  }) async {
    debugPrint('🔔 [DS] fetchClientes(page: $page, size: $size) → START');
    final from = page * size, to = from + size - 1;
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select('id, nombre, telefono, direccion, negocio, '
            'estado_real, dias_reales, score_actual, has_history, '
            'latitud, longitud') // <--- MODIFICADO AQUÍ
        .order('id', ascending: true)
        .range(from, to);
    debugPrint('🔍 [DS] fetchClientes raw = $raw');
    final list = (raw as List)
        .map((m) => ClienteRead.fromMap(m as Map<String, dynamic>))
        .toList();
    debugPrint('✅ [DS] fetchClientes devolvió ${list.length} clientes');
    return list;
  }

  @override
  Future<List<ClienteRead>> searchClientes({
    required String term,
    int page = 0,
    int size = 20,
  }) async {
    debugPrint(
        '🔔 [DS] searchClientes(term: "$term", page: $page, size: $size)');
    final filter = '%${term.toLowerCase()}%';
    final from = page * size, to = from + size - 1;
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select('id, nombre, telefono, direccion, negocio, '
            'estado_real, dias_reales, score_actual, has_history, '
            'latitud, longitud') // <--- MODIFICADO AQUÍ
        .or('nombre.ilike.$filter,telefono.ilike.$filter,negocio.ilike.$filter')
        .order('id', ascending: true)
        .range(from, to);
    debugPrint('🔍 [DS] searchClientes raw = $raw');
    final list = (raw as List)
        .map((m) => ClienteRead.fromMap(m as Map<String, dynamic>))
        .toList();
    debugPrint('✅ [DS] searchClientes devolvió ${list.length} registros');
    return list;
  }

  @override
  Future<List<ClienteRead>> fetchClientesPendientes({
    int page = 0,
    int size = 20,
  }) async {
    debugPrint('🔔 [DS] fetchClientesPendientes(page: $page, size: $size)');
    final from = page * size, to = from + size - 1;
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select('id, nombre, telefono, direccion, negocio, '
            'estado_real, dias_reales, score_actual, has_history, '
            'latitud, longitud') // <--- MODIFICADO AQUÍ
        .gt('dias_reales', 0)
        .order('dias_reales', ascending: true)
        .order('id', ascending: true)
        .range(from, to);
    debugPrint('🔍 [DS] fetchClientesPendientes raw = $raw');
    final list = (raw as List)
        .map((m) => ClienteRead.fromMap(m as Map<String, dynamic>))
        .toList();
    debugPrint('✅ [DS] fetchClientesPendientes devolvió ${list.length}');
    return list;
  }

  @override
  Future<ClienteDetailRead> fetchClienteById(int id) async {
    debugPrint('🔔 [DS] fetchClienteById(id: $id)');
    final raw = await _supabase
        .from('v_clientes_con_estado')
        .select('id, nombre, telefono, direccion, negocio, '
            'estado_real, dias_reales, score_actual, has_history, '
            'monto_solicitado, fecha_primer_pago, cuota_diaria, '
            'ultima_cuota, plazo_dias, saldo_pendiente, '
            'latitud, longitud') // <--- MODIFICADO AQUÍ (asegúrate que la coma anterior esté)
        .eq('id', id)
        .single();
    debugPrint('🔍 [DS] fetchClienteById raw = $raw');
    final cliente = ClienteDetailRead.fromMap(raw);
    debugPrint('✅ [DS] fetchClienteById devolvió: ${cliente.nombre}');
    return cliente;
  }

  @override
  Future<List<PagoRead>> fetchPagos(int clienteId) async {
    debugPrint('🔔 [DS] fetchPagos(clienteId: $clienteId)');
    final raw = await _supabase
        .from('pagos')
        .select('numero_cuota')
        .eq('cliente_id', clienteId);
    debugPrint('🔍 [DS] fetchPagos raw = $raw');
    final list = (raw as List)
        .map((e) => PagoRead.fromMap(e as Map<String, dynamic>))
        .toList();
    debugPrint('✅ [DS] fetchPagos devolvió ${list.length} pagos');
    return list;
  }

  @override
  Future<List<CronogramaRead>> fetchCronograma(int clienteId) async {
    debugPrint('🔔 [DS] fetchCronograma(clienteId: $clienteId)');
    final raw = await _supabase
        .from('cronograma')
        .select('numero_cuota, monto_cuota, fecha_pagado')
        .eq('cliente_id', clienteId)
        .order('numero_cuota');
    debugPrint('🔍 [DS] fetchCronograma raw = $raw');
    final list = (raw as List)
        .map((e) => CronogramaRead.fromMap(e as Map<String, dynamic>))
        .toList();
    debugPrint('✅ [DS] fetchCronograma devolvió ${list.length} cuotas');
    return list;
  }

  @override
  Future<List<HistorialRead>> fetchHistoriales(int clienteId) async {
    debugPrint('🔔 [DS] fetchHistoriales(clienteId: $clienteId)');
    // Nota: v_creditos_cerrados probablemente también necesite ser actualizada
    // si quieres mostrar latitud/longitud del historial.
    // Por ahora, esta función no parece necesitar lat/lng directamente.
    final raw = await _supabase
        .from('v_creditos_cerrados')
        .select(
          'fecha_inicio, fecha_cierre_real, monto_solicitado, '
          'total_pagado, dias_totales, dias_atraso_max',
        )
        .eq('credito_id',
            clienteId) // Asumiendo que el ID en v_creditos_cerrados se llama credito_id
        .order('fecha_cierre_real', ascending: true);
    debugPrint('🔍 [DS] fetchHistoriales raw = $raw');
    final list = (raw as List)
        .map((m) => HistorialRead.fromMap(m as Map<String, dynamic>))
        .toList();
    debugPrint('✅ [DS] fetchHistoriales devolvió ${list.length} registros');
    return list;
  }

  @override
  Future<bool> registrarPago(int clienteId, int numeroCuota, num monto) async {
    debugPrint('🔔 [DS] registrarPago → clienteId=$clienteId, '
        'cuota=$numeroCuota, monto=$monto');
    try {
      final res = await _supabase.from('pagos').insert({
        'cliente_id': clienteId,
        'numero_cuota': numeroCuota,
        'monto_pagado': monto,
      });
      debugPrint('✅ [DS] insert pagos result = $res');
      return true;
    } catch (e) {
      debugPrint('❌ [DS] Error registrarPago: $e');
      return false;
    }
  }

  @override
  Future<bool> registrarEvento(int clienteId, String descripcion) async {
    debugPrint('🔔 [DS] registrarEvento → clienteId=$clienteId, '
        'descripcion="$descripcion"');
    try {
      final res = await _supabase.from('historial_eventos').insert({
        'cliente_id': clienteId,
        'descripcion': descripcion,
      });
      debugPrint('✅ [DS] insert evento result = $res');
      return true;
    } catch (e) {
      debugPrint('❌ [DS] Error registrarEvento: $e');
      return false;
    }
  }

  @override
  Future<bool> nuevoCreditoRpc({
    required int clienteId,
    required double montoSolicitado,
    required int plazoDias,
    required String fechaPrimerPago,
  }) async {
    debugPrint('🔔 [DS] llamando abrir_nuevo_credito RPC → '
        'clienteId=$clienteId, monto=$montoSolicitado, '
        'plazo=$plazoDias, fecha=$fechaPrimerPago');
    try {
      await _supabase.rpc('abrir_nuevo_credito', params: {
        'p_cliente_id': clienteId,
        'p_monto_solicitado': montoSolicitado,
        'p_plazo_dias': plazoDias,
        'p_fecha_primer_pago': fechaPrimerPago,
      });
      debugPrint('✅ [DS] abrir_nuevo_credito OK');
      return true;
    } catch (e, st) {
      debugPrint('❌ [DS] abrir_nuevo_credito ERROR: $e\n$st');
      return false;
    }
  }
}
