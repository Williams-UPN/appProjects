// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'repositories/cliente_repository.dart';
import 'viewmodels/cliente_nuevo_viewmodel.dart';
import 'viewmodels/lista_clientes_viewmodel.dart';
import 'viewmodels/clientes_pendientes_viewmodel.dart';

import 'screens/splash.dart';
import 'screens/main_menu/main_menu_screen.dart';
import 'screens/lista_de_clientes/lista_de_clientes_screen.dart';
import 'screens/cliente_nuevo/cliente_nuevo_screen.dart';
import 'screens/cliente_pendiente/clientes_pendientes_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barra de estado completamente blanca
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
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
        Provider<ClienteRepository>(create: (_) => ClienteRepository()),
        ChangeNotifierProvider(
          create: (ctx) => ClienteNuevoViewModel(ctx.read<ClienteRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              ListaClientesViewModel(ctx.read<ClienteRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              ClientesPendientesViewModel(ctx.read<ClienteRepository>()),
        ),
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
        colorScheme: const ColorScheme.light(
          primary: Colors.white, // AppBar
          onPrimary: Colors.black, // texto/iconos en AppBar
          surface: Colors.white, // tarjetas y superficies Material
          onSurface: Colors.black, // texto en superficies
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBBDEFB),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
