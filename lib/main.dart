import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ← Añade esto
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Coloca el fondo blanco también en la barra de estado
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white, // Fondo blanco
      statusBarIconBrightness: Brightness.dark, // Iconos oscuros en Android
      statusBarBrightness: Brightness.light, // Para iOS
    ),
  );

  // Carga las variables de entorno
  await dotenv.load(fileName: '.env');

  // Inicializa Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Lanza la aplicación
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto Cobros',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
