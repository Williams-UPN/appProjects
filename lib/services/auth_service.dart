import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart';

class AuthService {
  static const String baseUrl = 'https://dlpvictozfwiyjgxgwif.supabase.co';
  
  /// Valida si el token del cobrador sigue siendo válido
  static Future<TokenValidationResult> validateToken() async {
    try {
      // Obtener token de la configuración de la app
      if (appConfig == null || appConfig!['cobrador_token'] == null) {
        return TokenValidationResult(
          isValid: false,
          reason: 'NO_TOKEN',
          message: 'No se encontró token de autenticación',
        );
      }
      
      final token = appConfig!['cobrador_token'] as String;
      var adminUrl = appConfig!['admin_url'] ?? 'http://localhost:3000';
      
      // Para desarrollo: permitir localhost y reemplazar con IP local
      if (adminUrl.contains('localhost')) {
        // CAMBIAR ESTA IP POR TU IP LOCAL
        adminUrl = adminUrl.replaceAll('localhost', '192.168.1.100');
        print('[AuthService] Usando IP local para desarrollo: $adminUrl');
      }
      
      print('[AuthService] Validando token: ${token.substring(0, 10)}...');
      print('[AuthService] Admin URL: $adminUrl');
      
      // Hacer petición de validación
      final response = await http.post(
        Uri.parse('$adminUrl/api/auth/validate-token'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout validando token');
        },
      );
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200 && data['valid'] == true) {
        print('[AuthService] ✅ Token válido para: ${data['cobrador']['nombre']}');
        return TokenValidationResult(
          isValid: true,
          cobradorData: data['cobrador'],
          message: data['message'],
        );
      } else {
        print('[AuthService] ❌ Token inválido: ${data['reason']}');
        return TokenValidationResult(
          isValid: false,
          reason: data['reason'] ?? 'UNKNOWN',
          message: data['message'] ?? 'Token inválido',
          cobradorData: data['cobrador'],
        );
      }
      
    } catch (e) {
      print('[AuthService] Error validando token: $e');
      return TokenValidationResult(
        isValid: false,
        reason: 'NETWORK_ERROR',
        message: 'Error de conexión: $e',
      );
    }
  }
  
  /// Verificación rápida solo para comprobar si el cobrador existe
  static Future<bool> quickTokenCheck() async {
    try {
      if (appConfig == null || appConfig!['cobrador_token'] == null) {
        return false;
      }
      
      final token = appConfig!['cobrador_token'] as String;
      final adminUrl = appConfig!['admin_url'] ?? 'http://localhost:3000';
      
      final response = await http.get(
        Uri.parse('$adminUrl/api/auth/validate-token?token=$token'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['valid'] == true;
      }
      
      return false;
    } catch (e) {
      print('[AuthService] Error en verificación rápida: $e');
      return false;
    }
  }
}

class TokenValidationResult {
  final bool isValid;
  final String? reason;
  final String? message;
  final Map<String, dynamic>? cobradorData;
  
  TokenValidationResult({
    required this.isValid,
    this.reason,
    this.message,
    this.cobradorData,
  });
  
  bool get isTokenNotFound => reason == 'TOKEN_NOT_FOUND';
  bool get isCobradorDisabled => reason == 'COBRADOR_DISABLED';
  bool get isNetworkError => reason == 'NETWORK_ERROR';
  bool get isServerError => reason == 'SERVER_ERROR';
  
  String get cobradorNombre => cobradorData?['nombre'] ?? 'Usuario';
  String get cobradorDni => cobradorData?['dni'] ?? '';
  String get cobradorEstado => cobradorData?['estado'] ?? '';
}