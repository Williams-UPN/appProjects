import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config_reader.dart'; // Agregar este import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Cargar configuración embebida
  await ConfigReader.initialize();
  
  // Inicializar Supabase
  await Supabase.initialize(
    url: ConfigReader.supabaseUrl.isNotEmpty 
         ? ConfigReader.supabaseUrl 
         : 'TU_SUPABASE_URL_ACTUAL', // Usa tu URL actual como fallback
    anonKey: ConfigReader.supabaseKey.isNotEmpty 
             ? ConfigReader.supabaseKey 
             : 'TU_SUPABASE_KEY_ACTUAL', // Usa tu key actual como fallback
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Cobros',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _getInitialScreen(),
    );
  }
  
  Widget _getInitialScreen() {
    // Si hay configuración válida y auto-login activado
    if (ConfigReader.hasValidConfig() && ConfigReader.autoLogin) {
      print('🚀 Auto-login activado para: ${ConfigReader.cobradorNombre}');
      
      // Aquí debes retornar tu pantalla principal
      // Por ejemplo: return MainMenuScreen();
      
      // Por ahora retornamos una pantalla de demo
      return AutoLoginScreen();
    }
    
    // Si no, ir al flujo normal (Splash o Login)
    // return SplashScreen(); // Tu pantalla normal
    
    // Por ahora retornamos una pantalla de demo
    return NormalLoginScreen();
  }
}

// Pantalla de demo para auto-login
class AutoLoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 100, color: Colors.green),
            SizedBox(height: 20),
            Text(
              '¡Bienvenido!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              ConfigReader.cobradorNombre ?? 'Cobrador',
              style: TextStyle(fontSize: 24, color: Colors.blue[700]),
            ),
            SizedBox(height: 10),
            Text(
              'DNI: ${ConfigReader.cobradorDni ?? 'N/A'}',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                // Aquí navegarías a tu menú principal
                // Navigator.pushReplacement(context, MaterialPageRoute(
                //   builder: (_) => MainMenuScreen()
                // ));
              },
              icon: Icon(Icons.arrow_forward),
              label: Text('Continuar al Menú'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Pantalla de demo para login normal
class NormalLoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text(
              'Login Normal',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'No se encontró configuración embebida',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}