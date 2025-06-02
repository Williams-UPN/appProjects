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
  Future<List<HistorialRead>> getHistoriales(int clienteId);
  Future<bool> registrarPago(
    int clienteId, 
    int numeroCuota, 
    num monto,
    {double? latitud, double? longitud, String? direccion}
  );
  Future<bool> registrarEvento(int clienteId, String descripcion);
  Future<bool> refinanciar(int clienteId, double montoAdicional, int plazoDias);
  Future<bool> nuevoCredito(
    int clienteId,
    double montoSolicitado,
    int plazoDias,
    DateTime fechaPrimerPago,
  );
}

class ClienteRepositoryImpl implements ClienteRepository {
  final SupabaseClient _supabase;
  final ClienteDatasource _ds;

  ClienteRepositoryImpl(this._supabase, this._ds);

  @override
  Future<bool> crearCliente(Cliente c) async {
    // ← 1) Trazar datos entrantes
    debugPrint('🔔 [Repo] crearCliente: ${c.toJson()}');
    try {
      await _supabase.from('clientes').insert(c.toJson());
      // ← 2) Confirmar éxito
      debugPrint('✅ [Repo] insert OK');
      return true;
    } catch (e) {
      // ← 3) Loguear el error lanzado
      debugPrint('❌ [Repo] insert ERROR: $e');
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
  Future<List<HistorialRead>> getHistoriales(int clienteId) async {
    debugPrint('🔔 [Repo] getHistoriales: clienteId=$clienteId');
    final historiales = await _ds.fetchHistoriales(clienteId);
    debugPrint(
        '🔔 [Repo] fetchHistoriales devolvió ${historiales.length} registros');
    return historiales;
  }

  @override
  Future<bool> registrarPago(
    int clienteId, 
    int numeroCuota, 
    num monto,
    {double? latitud, double? longitud, String? direccion}
  ) async {
    debugPrint('🔔 [Repo] registrarPago -> '
        'clienteId=$clienteId, cuota=$numeroCuota, monto=$monto, '
        'lat=$latitud, lng=$longitud');
    
    final success = await _ds.registrarPago(
      clienteId, 
      numeroCuota, 
      monto,
      latitud: latitud,
      longitud: longitud,
      direccion: direccion,
    );
    
    debugPrint('🔔 [Repo] _ds.registrarPago devolvió: $success');
    return success;
  }

  @override
  Future<bool> registrarEvento(int clienteId, String descripcion) async {
    debugPrint(
        '🔔 [Repo] registrarEvento: clienteId=$clienteId, descripcion="$descripcion"');
    final success = await _ds.registrarEvento(clienteId, descripcion);
    debugPrint('🔔 [Repo] _ds.registrarEvento devolvió: $success');
    return success;
  }

  @override
  Future<bool> refinanciar(
      int clienteId, double montoAdicional, int plazoDias) async {
    try {
      debugPrint('🔔 [Repo] INICIANDO refinanciar: '
          'clienteId=$clienteId, montoAdicional=$montoAdicional, plazoDias=$plazoDias');

      // 1) Leer el saldo pendiente actual
      final record = await _supabase
          .from('clientes')
          .select('saldo_pendiente')
          .eq('id', clienteId)
          .single();
      final currentSaldo = (record['saldo_pendiente'] as num).toDouble();
      debugPrint('🔍 [Repo] saldo_pendiente actual = $currentSaldo');

      // 2) Calcular el nuevo monto_solicitado
      final nuevoMonto = currentSaldo + montoAdicional;
      debugPrint('🔍 [Repo] nuevo monto_solicitado = $nuevoMonto');

      // 3) Preparar payload de UPDATE
      final payload = {
        'monto_solicitado': nuevoMonto,
        'plazo_dias': plazoDias,
        'fecha_primer_pago': DateTime.now().toUtc().toIso8601String(),
      };
      debugPrint('✏️ [Repo] payload UPDATE clientes: $payload');

      // 4) Ejecutar UPDATE
      final res =
          await _supabase.from('clientes').update(payload).eq('id', clienteId);
      debugPrint('✅ [Repo] UPDATE refinanciar devolvió: $res');

      return true;
    } catch (e) {
      debugPrint('❌ [Repo] refinanciar ERROR: $e');
      return false;
    }
  }

  @override
  Future<bool> nuevoCredito(
    int clienteId,
    double montoSolicitado,
    int plazoDias,
    DateTime fechaPrimerPago,
  ) async {
    final isoDate = fechaPrimerPago.toIso8601String().split('T').first;
    debugPrint('🔔 [Repo] INICIANDO nuevoCredito RPC → '
        'clienteId=$clienteId, monto=$montoSolicitado, plazo=$plazoDias, fecha=$isoDate');

    final ok = await _ds.nuevoCreditoRpc(
      clienteId: clienteId,
      montoSolicitado: montoSolicitado,
      plazoDias: plazoDias,
      fechaPrimerPago: isoDate,
    );

    debugPrint(ok
        ? '✅ [Repo] nuevoCredito RPC OK'
        : '❌ [Repo] nuevoCredito RPC FALLÓ');
    return ok;
  }
}
