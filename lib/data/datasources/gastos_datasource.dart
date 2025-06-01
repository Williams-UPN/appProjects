// lib/data/datasources/gastos_datasource.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../../models/gasto.dart';

abstract class GastosDatasource {
  Future<String?> uploadFoto(File imageFile);
  Future<bool> crearGasto(Gasto gasto);
  Future<List<Gasto>> fetchGastos({int page = 0, int size = 20});
}

class SupabaseGastosDatasource implements GastosDatasource {
  final SupabaseClient _supabase;

  SupabaseGastosDatasource(this._supabase) {
    debugPrint('🔌 [GastosDS] SupabaseGastosDatasource inicializado');
  }

  @override
  Future<String?> uploadFoto(File imageFile) async {
    try {
      debugPrint('🔔 [GastosDS] Iniciando upload de foto ULTRA-LIGERA...');

      // Leer la imagen
      final Uint8List imageBytes = await imageFile.readAsBytes();
      debugPrint(
          '📊 [GastosDS] Tamaño original: ${(imageBytes.length / 1024).toStringAsFixed(1)} KB');

      // Convertir y optimizar imagen
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ [GastosDS] No se pudo decodificar la imagen');
        return null;
      }

      debugPrint(
          '📐 [GastosDS] Dimensiones originales: ${image.width}x${image.height}');

      // OPTIMIZACIÓN AGRESIVA: Redimensionar a máximo 512x512 (muy ligero)
      img.Image resizedImage = image;
      const int maxSize = 512; // Reducido de 1024 a 512 para fotos más ligeras

      if (image.width > maxSize || image.height > maxSize) {
        if (image.width > image.height) {
          resizedImage = img.copyResize(image, width: maxSize);
        } else {
          resizedImage = img.copyResize(image, height: maxSize);
        }
        debugPrint(
            '🔄 [GastosDS] Redimensionado a: ${resizedImage.width}x${resizedImage.height}');
      }

      // COMPRESIÓN AGRESIVA: JPG con calidad 60% (muy ligero pero legible)
      final Uint8List optimizedBytes = Uint8List.fromList(img.encodeJpg(
              resizedImage,
              quality: 60) // CORREGIDO: encodeJpg en lugar de encodeWebP
          );

      debugPrint(
          '📊 [GastosDS] Tamaño optimizado: ${(optimizedBytes.length / 1024).toStringAsFixed(1)} KB');
      debugPrint(
          '💾 [GastosDS] Reducción: ${(((imageBytes.length - optimizedBytes.length) / imageBytes.length) * 100).toStringAsFixed(1)}%');

      // Generar nombre único para el archivo
      final String fileName =
          'gasto_${DateTime.now().millisecondsSinceEpoch}.jpg'; // CORREGIDO: .jpg
      final String filePath = 'gastos-fotos/$fileName';

      debugPrint('🔍 [GastosDS] Subiendo archivo optimizado: $filePath');

      // Subir a Supabase Storage
      await _supabase.storage
          .from('gastos-fotos')
          .uploadBinary(filePath, optimizedBytes);

      // Obtener URL pública
      final String publicUrl =
          _supabase.storage.from('gastos-fotos').getPublicUrl(filePath);

      debugPrint(
          '✅ [GastosDS] Foto ultra-ligera subida exitosamente: $publicUrl');
      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ [GastosDS] Error al subir foto: $e');
      debugPrint('❌ [GastosDS] StackTrace: $stackTrace');
      return null;
    }
  }

  @override
  Future<bool> crearGasto(Gasto gasto) async {
    debugPrint('🔔 [GastosDS] crearGasto: ${gasto.toJson()}');
    try {
      await _supabase.from('gastos').insert(gasto.toJson());

      debugPrint('✅ [GastosDS] Gasto creado exitosamente');
      return true;
    } catch (e) {
      debugPrint('❌ [GastosDS] Error al crear gasto: $e');
      return false;
    }
  }

  @override
  Future<List<Gasto>> fetchGastos({int page = 0, int size = 20}) async {
    debugPrint('🔔 [GastosDS] fetchGastos(page: $page, size: $size)');
    try {
      final from = page * size;
      final to = from + size - 1;

      final response = await _supabase
          .from('gastos')
          .select('*')
          .order('fecha_gasto', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to);

      debugPrint('🔍 [GastosDS] fetchGastos raw = $response');

      final List<Gasto> gastos = (response as List)
          .map((map) => Gasto.fromMap(map as Map<String, dynamic>))
          .toList();

      debugPrint('✅ [GastosDS] fetchGastos devolvió ${gastos.length} gastos');
      return gastos;
    } catch (e) {
      debugPrint('❌ [GastosDS] Error al obtener gastos: $e');
      return [];
    }
  }
}
