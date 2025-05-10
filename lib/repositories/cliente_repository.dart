// lib/repositories/cliente_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/datasources/cliente_datasource.dart';
import '../models/cliente.dart';
import '../models/cliente_read.dart';

/// Interfaz que usan tus ViewModels.
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
}

/// Implementación que delega en el DataSource (y usa Supabase sólo para crear).
class ClienteRepositoryImpl implements ClienteRepository {
  final SupabaseClient _supabase;
  final ClienteDatasource _ds;

  ClienteRepositoryImpl(this._supabase, this._ds);

  @override
  Future<bool> crearCliente(Cliente c) => _supabase
      .from('clientes')
      .insert(c.toJson())
      .then((r) => r.error == null);

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
}
