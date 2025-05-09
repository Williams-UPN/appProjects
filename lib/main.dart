import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'screens/splash.dart';
import 'screens/main_menu/main_menu_screen.dart';
import 'screens/lista_de_clientes/lista_de_clientes_screen.dart';
import 'screens/cliente_nuevo/cliente_nuevo_screen.dart';
import 'screens/cliente_pendiente/cliente_pendiente_screen.dart';

import 'viewmodels/cliente_nuevo_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // → tu barra de estado blanca
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ClienteNuevoViewModel()),
        // otros ViewModels aquí...
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proyecto Cobros',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (_) => const SplashScreen(),
        '/menu': (_) => const MainMenuScreen(),
        '/lista': (_) => const ListaDeClientesScreen(),
        '/nuevo': (_) => const ClienteNuevoScreen(),
        '/pendientes': (_) => const ClientesPendientesScreen(),
      },
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),

        // ——————————————————————————————
        // aquí mantenemos tu estilo de botones "pill"
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBBDEFB), // tu azul claro
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: const StadiumBorder(), // pill shape
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        // ——————————————————————————————
      ),
    );
  }
}
