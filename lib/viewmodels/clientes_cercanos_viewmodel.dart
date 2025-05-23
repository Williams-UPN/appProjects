// lib/viewmodels/clientes_cercanos_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/cliente_con_distancia.dart';
import '../repositories/cliente_repository.dart'; // Asegúrate que esta ruta sea correcta

class ClientesCercanosViewModel extends ChangeNotifier {
  final ClienteRepository _clienteRepository;

  ClientesCercanosViewModel(this._clienteRepository);

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  List<ClienteConDistancia> _clientesConDistancia = [];
  List<ClienteConDistancia> get clientesOrdenadosPorDistancia =>
      _clientesConDistancia;

  Position? _ubicacionActual;
  Position? get ubicacionActual => _ubicacionActual;

  Future<Position?> _obtenerUbicacionActualConPermisos() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isPermanentlyDenied) {
      _mensajeError =
          "Permiso de ubicación denegado permanentemente. Habilítelo en la configuración.";
      // Considerar abrir app settings: await openAppSettings();
      return null;
    }

    if (!status.isGranted) {
      _mensajeError = "Permiso de ubicación denegado.";
      return null;
    }

    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      _mensajeError = "Los servicios de ubicación están desactivados.";
      // Considerar abrir location settings: await Geolocator.openLocationSettings();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
          // ignore: deprecated_member_use
          desiredAccuracy: LocationAccuracy.medium);
    } catch (e) {
      _mensajeError = "Error al obtener la ubicación: ${e.toString()}";
      return null;
    }
  }

  Future<void> cargarClientesCercanos(
      {double maxDistanciaKmParaFiltrar = 0}) async {
    _estaCargando = true;
    _mensajeError = null;
    _clientesConDistancia = []; // Limpiar resultados anteriores
    notifyListeners();

    _ubicacionActual = await _obtenerUbicacionActualConPermisos();

    if (_ubicacionActual == null) {
      // _mensajeError ya fue establecido en _obtenerUbicacionActualConPermisos
      _estaCargando = false;
      notifyListeners();
      return;
    }

    try {
      // Asumimos que fetchClientes() sin paginación devuelve todos,
      // o ajusta para obtener todos los clientes que necesites.
      // Si tienes muchos clientes, considera una estrategia de paginación o filtro en el backend.
      final todosLosClientes = await _clienteRepository.fetchClientes(
          page: 0, size: 1000); // Ajusta size según necesidad

      if (todosLosClientes.isEmpty) {
        _mensajeError = "No se encontraron clientes.";
        _estaCargando = false;
        notifyListeners();
        return;
      }

      List<ClienteConDistancia> tempClientesConDistancia = [];
      for (var cliente in todosLosClientes) {
        if (cliente.latitud != null && cliente.longitud != null) {
          double distanciaMetros = Geolocator.distanceBetween(
            _ubicacionActual!.latitude,
            _ubicacionActual!.longitude,
            cliente.latitud!,
            cliente.longitud!,
          );
          tempClientesConDistancia.add(
            ClienteConDistancia(
                cliente: cliente, distanciaMetros: distanciaMetros),
          );
        }
      }

      // Ordenar por distancia
      tempClientesConDistancia
          .sort((a, b) => a.distanciaMetros.compareTo(b.distanciaMetros));

      if (maxDistanciaKmParaFiltrar > 0) {
        _clientesConDistancia = tempClientesConDistancia
            .where(
                (c) => (c.distanciaMetros / 1000) <= maxDistanciaKmParaFiltrar)
            .toList();
        if (_clientesConDistancia.isEmpty &&
            tempClientesConDistancia.isNotEmpty) {
          _mensajeError =
              "No hay clientes dentro del radio de ${maxDistanciaKmParaFiltrar}km. El más cercano está a ${(tempClientesConDistancia.first.distanciaMetros / 1000).toStringAsFixed(1)}km.";
        }
      } else {
        _clientesConDistancia = tempClientesConDistancia;
      }
    } catch (e) {
      _mensajeError = "Error al cargar la lista de clientes: ${e.toString()}";
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }
}
