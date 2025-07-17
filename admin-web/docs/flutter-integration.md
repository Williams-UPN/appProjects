# Integración Flutter con Sistema APK

## 1. Agregar archivo de configuración en Flutter

### Crear `assets/config/app_config.json`:
```json
{
  "cobrador_token": "PLACEHOLDER_TOKEN",
  "cobrador_nombre": "PLACEHOLDER_NOMBRE",
  "cobrador_dni": "PLACEHOLDER_DNI",
  "supabase_url": "https://dlpvictozfwiyjgxgwif.supabase.co",
  "supabase_key": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRscHZpY3RvemZ3aXlqZ3hnd2lmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ2OTA2NTYsImV4cCI6MjA2MDI2NjY1Nn0.WZrvX1sBLZ65xpZ3bK_50A_WhtoYjsQWvcJNzk3Kuoc",
  "auto_login": true,
  "version": "1.0.0"
}
```

### Actualizar `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/config/
```

## 2. Modificar main.dart

```dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Clase para manejar configuración embebida
class EmbeddedConfig {
  final String? cobradorToken;
  final String? cobradorNombre;
  final String? cobradorDni;
  final String supabaseUrl;
  final String supabaseKey;
  final bool autoLogin;
  
  EmbeddedConfig({
    this.cobradorToken,
    this.cobradorNombre,
    this.cobradorDni,
    required this.supabaseUrl,
    required this.supabaseKey,
    this.autoLogin = false,
  });
  
  factory EmbeddedConfig.fromJson(Map<String, dynamic> json) {
    return EmbeddedConfig(
      cobradorToken: json['cobrador_token'],
      cobradorNombre: json['cobrador_nombre'],
      cobradorDni: json['cobrador_dni'],
      supabaseUrl: json['supabase_url'],
      supabaseKey: json['supabase_key'],
      autoLogin: json['auto_login'] ?? false,
    );
  }
}

// Variable global para la configuración
late EmbeddedConfig appConfig;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar configuración embebida
  appConfig = await loadEmbeddedConfig();
  
  // Inicializar Supabase con credenciales embebidas
  await Supabase.initialize(
    url: appConfig.supabaseUrl,
    anonKey: appConfig.supabaseKey,
  );
  
  // Si hay auto-login configurado
  if (appConfig.autoLogin && appConfig.cobradorToken != null) {
    // Guardar en almacenamiento local para uso futuro
    await saveCobradorCredentials(appConfig);
  }
  
  runApp(MyApp());
}

Future<EmbeddedConfig> loadEmbeddedConfig() async {
  try {
    final String response = await rootBundle.loadString('assets/config/app_config.json');
    final data = json.decode(response);
    return EmbeddedConfig.fromJson(data);
  } catch (e) {
    print('Error cargando configuración embebida: $e');
    // Retornar configuración por defecto
    return EmbeddedConfig(
      supabaseUrl: 'https://dlpvictozfwiyjgxgwif.supabase.co',
      supabaseKey: 'tu_anon_key',
    );
  }
}

Future<void> saveCobradorCredentials(EmbeddedConfig config) async {
  // Guardar en SharedPreferences o almacenamiento seguro
  // Para que la app recuerde las credenciales
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Cobros',
      home: appConfig.autoLogin && appConfig.cobradorToken != null
          ? MainMenuScreen() // Ir directo al menú principal
          : SplashScreen(),   // Mostrar splash normal
    );
  }
}
```

## 3. Modificar SplashScreen

```dart
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }
  
  Future<void> _checkAutoLogin() async {
    // Si hay credenciales embebidas, auto-login
    if (appConfig.autoLogin && appConfig.cobradorToken != null) {
      // Registrar cobrador en sistema
      await _registerCobrador();
      
      // Ir directo al menú principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainMenuScreen()),
      );
    } else {
      // Flujo normal de la app
      await Future.delayed(Duration(seconds: 2));
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }
  
  Future<void> _registerCobrador() async {
    try {
      // Registrar última conexión
      await Supabase.instance.client
        .from('cobradores')
        .update({
          'ultima_conexion': DateTime.now().toIso8601String(),
        })
        .eq('token_acceso', appConfig.cobradorToken);
    } catch (e) {
      print('Error registrando cobrador: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo de la app
            Icon(Icons.monetization_on, size: 100, color: Colors.blue),
            SizedBox(height: 20),
            Text(
              'Sistema de Cobros',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (appConfig.cobradorNombre != null)
              Text(
                'Bienvenido ${appConfig.cobradorNombre}',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
```

## 4. Crear servicio para tracking

```dart
// lib/services/cobrador_service.dart
class CobradorService {
  static final supabase = Supabase.instance.client;
  
  // Registrar actividad del cobrador
  static Future<void> trackActivity(String activity) async {
    if (appConfig.cobradorToken == null) return;
    
    try {
      await supabase.from('cobrador_activity').insert({
        'cobrador_id': await getCobradorId(),
        'activity': activity,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error tracking activity: $e');
    }
  }
  
  // Obtener ID del cobrador por token
  static Future<String?> getCobradorId() async {
    try {
      final response = await supabase
        .from('cobradores')
        .select('id')
        .eq('token_acceso', appConfig.cobradorToken)
        .single();
      
      return response['id'];
    } catch (e) {
      return null;
    }
  }
  
  // Actualizar última conexión
  static Future<void> updateLastConnection() async {
    if (appConfig.cobradorToken == null) return;
    
    try {
      await supabase
        .from('cobradores')
        .update({
          'ultima_conexion': DateTime.now().toIso8601String(),
        })
        .eq('token_acceso', appConfig.cobradorToken);
    } catch (e) {
      print('Error updating connection: $e');
    }
  }
}
```

## 5. Compilar APK

```bash
# En tu proyecto Flutter
flutter clean
flutter pub get
flutter build apk --release

# El APK estará en:
# build/app/outputs/flutter-apk/app-release.apk
```

## 6. Copiar APK al proyecto admin-web

```bash
# Copiar el APK generado
cp build/app/outputs/flutter-apk/app-release.apk /ruta/admin-web/storage/base-apk/app-release.apk
```

## 7. Probar el sistema completo

1. Crear nuevo cobrador en admin-web
2. El sistema generará APK con credenciales embebidas
3. Instalar APK en dispositivo
4. La app debería abrir directamente sin login
5. Verificar en base de datos que se actualiza última_conexion