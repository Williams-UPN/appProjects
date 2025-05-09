// lib/repositories/cliente_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente.dart';

class ClienteRepository {
  final _supabase = Supabase.instance.client;

  /// Inserta un nuevo cliente en la tabla 'clientes'.
  /// Devuelve true si todo OK, false si hubo error.
  Future<bool> crearCliente(Cliente c) async {
    final resp = await _supabase.from('clientes').insert(c.toJson());
    return resp.error == null;
  }
}
