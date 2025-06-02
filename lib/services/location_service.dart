// lib/services/location_service.dart

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

// Modelo simple para los datos de ubicación
class LocationData {
  final double latitude;
  final double longitude;
  final String address;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationService {
  // Singleton pattern
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Verificar si tenemos permisos
  Future<bool> checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  // Solicitar permisos
  Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  // Obtener ubicación actual con dirección
  Future<LocationData?> getCurrentLocation() async {
    try {
      // Verificar permisos primero
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) {
          debugPrint('LocationService: Permisos denegados');
          return null;
        }
      }

      // Verificar si el servicio está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Servicio de ubicación deshabilitado');
        return null;
      }

      // Obtener posición
      debugPrint('LocationService: Obteniendo posición...');
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint(
          'LocationService: Posición obtenida: ${position.latitude}, ${position.longitude}');

      // Obtener dirección desde coordenadas
      debugPrint('LocationService: Iniciando geocoding inverso...');
      String address = await _getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      debugPrint('LocationService: Dirección obtenida: $address');

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
      );
    } catch (e) {
      debugPrint('LocationService Error: $e');
      return null;
    }
  }

  // Obtener solo coordenadas (más rápido, sin geocoding)
  Future<Position?> getCoordinatesOnly() async {
    try {
      // Verificar permisos
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        hasPermission = await requestLocationPermission();
        if (!hasPermission) return null;
      }

      // Verificar servicio
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Obtener posición
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 7),
        ),
      );
    } catch (e) {
      debugPrint('LocationService Error (coordinates): $e');
      return null;
    }
  }

  // Convertir coordenadas a dirección
  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
      }

      final Placemark place = placemarks.first;

      // Construir dirección de forma similar a como lo haces en cliente_nuevo_screen
      String calle = place.thoroughfare ?? place.street ?? '';
      String numero = place.subThoroughfare ?? '';
      String nombreSubLocalidad = place.subLocality ?? '';
      String nombreLocalidad = place.locality ?? '';

      String constructedAddress = calle;
      if (numero.isNotEmpty) {
        constructedAddress +=
            (constructedAddress.isNotEmpty ? ' $numero' : numero);
      }

      if (nombreSubLocalidad.isNotEmpty &&
          !constructedAddress
              .toLowerCase()
              .contains(nombreSubLocalidad.toLowerCase())) {
        constructedAddress += constructedAddress.isNotEmpty
            ? ', $nombreSubLocalidad'
            : nombreSubLocalidad;
      }

      if (nombreLocalidad.isNotEmpty &&
          !constructedAddress
              .toLowerCase()
              .contains(nombreLocalidad.toLowerCase())) {
        constructedAddress += constructedAddress.isNotEmpty
            ? ', $nombreLocalidad'
            : nombreLocalidad;
      }

      return constructedAddress.isNotEmpty
          ? constructedAddress
          : 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
    } catch (e) {
      debugPrint('Error en geocoding inverso: $e');
      return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
    }
  }

  // Geocoding: dirección a coordenadas
  Future<LocationData?> getLocationFromAddress(String address) async {
    try {
      String searchAddress = address;
      // Si no tiene Lima o Perú, agregarlo
      if (!searchAddress.toLowerCase().contains('lima') &&
          !searchAddress.toLowerCase().contains('perú')) {
        searchAddress += ", Lima, Perú";
      }

      List<Location> locations = await locationFromAddress(searchAddress);
      if (locations.isEmpty) return null;

      final location = locations.first;

      // Obtener dirección formateada
      String formattedAddress = await _getAddressFromCoordinates(
          location.latitude, location.longitude);

      return LocationData(
        latitude: location.latitude,
        longitude: location.longitude,
        address: formattedAddress,
      );
    } catch (e) {
      debugPrint('LocationService Error (geocoding): $e');
      return null;
    }
  }
}
