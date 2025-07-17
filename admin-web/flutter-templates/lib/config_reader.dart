import 'dart:convert';
import 'package:flutter/services.dart';

class ConfigReader {
  static Map<String, dynamic>? _config;

  static Future<void> initialize() async {
    try {
      final String configString = 
          await rootBundle.loadString('assets/config/app_config.json');
      _config = json.decode(configString);
      print('✅ Configuración cargada: ${_config?['cobrador_nombre']}');
    } catch (e) {
      print('❌ Error cargando configuración: $e');
      _config = null;
    }
  }

  static String? get cobradorToken => _config?['cobrador_token'];
  static String? get cobradorNombre => _config?['cobrador_nombre'];
  static String? get cobradorDni => _config?['cobrador_dni'];
  static String get supabaseUrl => _config?['supabase_url'] ?? '';
  static String get supabaseKey => _config?['supabase_key'] ?? '';
  static bool get autoLogin => _config?['auto_login'] ?? false;

  static bool hasValidConfig() {
    return _config != null && 
           cobradorToken != null && 
           cobradorToken != 'PLACEHOLDER_TOKEN';
  }
}