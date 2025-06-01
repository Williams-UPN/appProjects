// lib/repositories/gastos_repository.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/datasources/gastos_datasource.dart';
import '../models/gasto.dart';

abstract class GastosRepository {
  Future<bool> crearGasto(Gasto gasto, {File? fotoFile});
  Future<List<Gasto>> fetchGastos({int page = 0, int size = 20});
}

class GastosRepositoryImpl implements GastosRepository {
  final GastosDatasource _datasource;

  GastosRepositoryImpl(this._datasource);

  @override
  Future<bool> crearGasto(Gasto gasto, {File? fotoFile}) async {
    debugPrint('🔔 [GastosRepo] crearGasto iniciado');

    try {
      // Si hay foto, subirla primero
      String? fotoUrl;
      if (fotoFile != null) {
        debugPrint('🔔 [GastosRepo] Subiendo foto ultra-ligera...');
        fotoUrl = await _datasource.uploadFoto(fotoFile);

        if (fotoUrl == null) {
          debugPrint('❌ [GastosRepo] Error al subir foto');
          return false;
        }
        debugPrint('✅ [GastosRepo] Foto subida: $fotoUrl');
      }

      // Crear nuevo gasto con la URL de la foto
      final gastoConFoto = Gasto(
        categoria: gasto.categoria,
        monto: gasto.monto,
        descripcion: gasto.descripcion,
        fotoUrl: fotoUrl,
        latitud: gasto.latitud,
        longitud: gasto.longitud,
        fechaGasto: gasto.fechaGasto ?? DateTime.now(),
      );

      // Guardar en base de datos
      final success = await _datasource.crearGasto(gastoConFoto);

      debugPrint(success
          ? '✅ [GastosRepo] Gasto creado exitosamente'
          : '❌ [GastosRepo] Error al crear gasto');

      return success;
    } catch (e) {
      debugPrint('❌ [GastosRepo] Error inesperado: $e');
      return false;
    }
  }

  @override
  Future<List<Gasto>> fetchGastos({int page = 0, int size = 20}) async {
    debugPrint('🔔 [GastosRepo] fetchGastos(page: $page, size: $size)');
    return await _datasource.fetchGastos(page: page, size: size);
  }
}
