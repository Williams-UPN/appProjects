// lib/viewmodels/agregar_gastos_viewmodel.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/gasto.dart';
import '../repositories/gastos_repository.dart';

class AgregarGastosViewModel extends ChangeNotifier {
  final GastosRepository _repository;
  final ImagePicker _imagePicker = ImagePicker();

  AgregarGastosViewModel(this._repository);

  // Estado del formulario
  String? _categoriaSeleccionada;
  double _monto = 0.0;
  String? _descripcion;
  File? _fotoSeleccionada;
  bool _isLoading = false;
  Position? _ubicacionActual;

  // Getters
  String? get categoriaSeleccionada => _categoriaSeleccionada;
  double get monto => _monto;
  String? get descripcion => _descripcion;
  File? get fotoSeleccionada => _fotoSeleccionada;
  bool get isLoading => _isLoading;
  Position? get ubicacionActual => _ubicacionActual;

  // Validaciones
  bool get formularioValido {
    if (_categoriaSeleccionada == null) return false;
    if (_monto <= 0) return false;
    if (_categoriaSeleccionada == 'Otro' &&
        (_descripcion == null || _descripcion!.trim().isEmpty)) {
      return false;
    }
    return true;
  }

  String? get errorCategoria {
    return _categoriaSeleccionada == null ? 'Selecciona una categoría' : null;
  }

  String? get errorMonto {
    return _monto <= 0 ? 'El monto debe ser mayor a 0' : null;
  }

  String? get errorDescripcion {
    if (_categoriaSeleccionada == 'Otro' &&
        (_descripcion == null || _descripcion!.trim().isEmpty)) {
      return 'La descripción es obligatoria para "Otro"';
    }
    return null;
  }

  // Setters
  void setCategoria(String categoria) {
    _categoriaSeleccionada = categoria;
    // Limpiar descripción si cambia de "Otro" a otra categoría
    if (categoria != 'Otro') {
      _descripcion = null;
    }
    notifyListeners();
  }

  void setMonto(double monto) {
    _monto = monto;
    notifyListeners();
  }

  void setDescripcion(String? descripcion) {
    _descripcion = descripcion;
    notifyListeners();
  }

  // Función para capturar foto
  Future<bool> capturarFoto({bool fromCamera = true}) async {
    try {
      debugPrint(
          '🔔 [GastosVM] Capturando foto desde ${fromCamera ? "cámara" : "galería"}');

      final XFile? image = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        _fotoSeleccionada = File(image.path);
        debugPrint('✅ [GastosVM] Foto seleccionada: ${image.path}');
        notifyListeners();
        return true;
      }

      debugPrint('⚠️ [GastosVM] No se seleccionó ninguna foto');
      return false;
    } catch (e) {
      debugPrint('❌ [GastosVM] Error al capturar foto: $e');
      return false;
    }
  }

  // Función para obtener ubicación
  Future<bool> obtenerUbicacion() async {
    try {
      debugPrint('🔔 [GastosVM] Obteniendo ubicación...');

      // Verificar permisos
      var status = await Permission.locationWhenInUse.status;
      if (status.isDenied) {
        status = await Permission.locationWhenInUse.request();
      }

      if (!status.isGranted) {
        debugPrint('⚠️ [GastosVM] Permiso de ubicación denegado');
        return false;
      }

      // Verificar si el servicio está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ [GastosVM] Servicio de ubicación deshabilitado');
        return false;
      }

      // Obtener ubicación
      _ubicacionActual = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.medium,
      );

      debugPrint(
          '✅ [GastosVM] Ubicación obtenida: ${_ubicacionActual?.latitude}, ${_ubicacionActual?.longitude}'); // CORREGIDO: longitude
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ [GastosVM] Error al obtener ubicación: $e');
      return false;
    }
  }

  // Función para remover foto
  void removerFoto() {
    _fotoSeleccionada = null;
    notifyListeners();
  }

  // Función principal para guardar gasto
  Future<bool> guardarGasto() async {
    debugPrint('🔔 [GastosVM] Iniciando guardado de gasto ultra-ligero...');

    if (!formularioValido) {
      debugPrint('❌ [GastosVM] Formulario inválido');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Crear objeto gasto
      final gasto = Gasto(
        categoria: _categoriaSeleccionada!,
        monto: _monto,
        descripcion: _descripcion,
        latitud: _ubicacionActual?.latitude,
        longitud: _ubicacionActual?.longitude, // CORREGIDO: longitude
        fechaGasto: DateTime.now(),
      );

      // Guardar a través del repository
      final success = await _repository.crearGasto(
        gasto,
        fotoFile: _fotoSeleccionada,
      );

      if (success) {
        debugPrint('✅ [GastosVM] Gasto ultra-ligero guardado exitosamente');
        limpiarFormulario();
      } else {
        debugPrint('❌ [GastosVM] Error al guardar gasto');
      }

      return success;
    } catch (e) {
      debugPrint('❌ [GastosVM] Error inesperado: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Función para limpiar formulario
  void limpiarFormulario() {
    _categoriaSeleccionada = null;
    _monto = 0.0;
    _descripcion = null;
    _fotoSeleccionada = null;
    _ubicacionActual = null;
    notifyListeners();
    debugPrint('🔄 [GastosVM] Formulario limpiado');
  }

  // CORREGIDO: Removido override innecesario
}
