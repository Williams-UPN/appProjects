import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/cliente_datasource.dart';
import '../models/cliente_read.dart';
import '../models/cliente.dart';
import '../models/cliente_detail_read.dart';
import '../models/pago_read.dart';
import '../models/cronograma_read.dart';
import '../models/historial_read.dart';

abstract class ClienteRepository {
  Future<bool> crearCliente(Cliente c);
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
  Future<ClienteDetailRead> getClienteById(int id);
  Future<List<PagoRead>> getPagos(int clienteId);
  Future<List<CronogramaRead>> getCronograma(int clienteId);
  Future<HistorialRead?> getHistorial(int clienteId);
  Future<bool> registrarPago(int clienteId, int numeroCuota, num monto);
  Future<bool> registrarEvento(int clienteId, String descripcion);
}

class ClienteRepositoryImpl implements ClienteRepository {
  final SupabaseClient _supabase;
  final ClienteDatasource _ds;

  ClienteRepositoryImpl(this._supabase, this._ds);

  @override
  Future<bool> crearCliente(Cliente c) async {
    try {
      await _supabase.from('clientes').insert(c.toJson());
      return true;
    } catch (e) {
      debugPrint('🔴 [Repo] Error crearCliente: $e');
      return false;
    }
  }

  @override
  Future<List<ClienteRead>> fetchClientes({int page = 0, int size = 20}) =>
      _ds.fetchClientes(page: page, size: size);

  @override
  Future<List<ClienteRead>> searchClientes({
    required String term,
    int page = 0,
    int size = 20,
  }) =>
      _ds.searchClientes(term: term, page: page, size: size);

  @override
  Future<List<ClienteRead>> fetchClientesPendientes({
    int page = 0,
    int size = 20,
  }) =>
      _ds.fetchClientesPendientes(page: page, size: size);

  @override
  Future<ClienteDetailRead> getClienteById(int id) => _ds.fetchClienteById(id);

  @override
  Future<List<PagoRead>> getPagos(int clienteId) => _ds.fetchPagos(clienteId);

  @override
  Future<List<CronogramaRead>> getCronograma(int clienteId) =>
      _ds.fetchCronograma(clienteId);

  @override
  Future<HistorialRead?> getHistorial(int clienteId) =>
      _ds.fetchHistorial(clienteId);

  @override
  Future<bool> registrarPago(int clienteId, int numeroCuota, num monto) async {
    debugPrint('🔔 [Repo] registrarPago -> '
        'clienteId=$clienteId, cuota=$numeroCuota, monto=$monto');
    final success = await _ds.registrarPago(clienteId, numeroCuota, monto);
    debugPrint('🔔 [Repo] _ds.registrarPago devolvió: $success');
    return success;
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
      debugPrint('🔴 [Repo] Error registrarEvento: $e');
      return false;
    }
  }
}
