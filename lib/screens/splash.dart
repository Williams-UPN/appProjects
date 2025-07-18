import 'package:flutter/material.dart';
import 'main_menu/main_menu_screen.dart';
import 'access_denied/access_denied_screen.dart';
import '../main.dart'; // Para acceder a appConfig
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Cargando...';
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _status = 'Verificando credenciales...';
      _isValidating = true;
    });

    // Esperar mínimo 2 segundos para mostrar splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Verificar token si existe configuración embebida
    if (appConfig != null && appConfig!['cobrador_token'] != null) {
      // Verificar si es un placeholder
      if (appConfig!['cobrador_token'] == 'PLACEHOLDER_TOKEN' || 
          appConfig!['cobrador_nombre'] == 'PLACEHOLDER_NOMBRE') {
        print('[SplashScreen] APK con configuración placeholder detectado');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AccessDeniedScreen(
                cobradorNombre: 'Usuario no configurado',
                motivo: 'APK no válido - Contacta al administrador',
              ),
            ),
          );
        }
        return;
      }
      
      setState(() {
        _status = 'Validando acceso...';
      });

      final result = await AuthService.validateToken();
      
      if (!mounted) return;

      if (result.isValid) {
        // Token válido, continuar a la app
        setState(() {
          _status = 'Acceso autorizado';
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MainMenuScreen(),
            ),
          );
        }
      } else {
        // Token inválido, mostrar pantalla de acceso denegado
        print('[SplashScreen] Token inválido: ${result.reason}');
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AccessDeniedScreen(
                cobradorNombre: result.cobradorNombre,
                motivo: _getMotiveMessage(result.reason),
              ),
            ),
          );
        }
      }
    } else {
      // Sin configuración embebida, continuar normalmente
      setState(() {
        _status = 'Iniciando aplicación...';
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainMenuScreen(),
          ),
        );
      }
    }
  }

  String _getMotiveMessage(String? reason) {
    switch (reason) {
      case 'TOKEN_NOT_FOUND':
        return 'Usuario no encontrado';
      case 'COBRADOR_DISABLED':
        return 'Cuenta desactivada';
      case 'NETWORK_ERROR':
        return 'Error de conexión';
      case 'SERVER_ERROR':
        return 'Error del servidor';
      case 'CONFIG_ERROR':
        return 'APK mal configurado';
      default:
        return 'Acceso no autorizado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF90CAF9),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (appConfig != null && appConfig!['cobrador_nombre'] != 'PLACEHOLDER_NOMBRE' && !_isValidating)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Bienvenido ${appConfig!['cobrador_nombre']}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
            if (_isValidating && appConfig != null && appConfig!['cobrador_nombre'] != 'PLACEHOLDER_NOMBRE')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Usuario: ${appConfig!['cobrador_nombre']}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
