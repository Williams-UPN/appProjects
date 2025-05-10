// lib/data/datasources/cliente_datasource.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/cliente_read.dart';

/// Capa de Data Source: sólo llamadas crudas a Supabase.
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
}
