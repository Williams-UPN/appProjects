// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'repositories/cliente_repository.dart';
import 'viewmodels/cliente_nuevo_viewmodel.dart';
import 'viewmodels/lista_clientes_viewmodel.dart';

import 'screens/splash.dart';
import 'screens/main_menu/main_menu_screen.dart';
import 'screens/lista_de_clientes/lista_de_clientes_screen.dart';
import 'screens/cliente_nuevo/cliente_nuevo_screen.dart';
import 'screens/cliente_pendiente/cliente_pendiente_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Barra de estado blanca
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
        // 1) Proveemos el repositorio centralizado
        Provider<ClienteRepository>(
          create: (_) => ClienteRepository(),
        ),

        // 2) Inyectamos el repo en el ViewModel de "Nuevo Cliente"
        ChangeNotifierProvider<ClienteNuevoViewModel>(
          create: (ctx) => ClienteNuevoViewModel(ctx.read<ClienteRepository>()),
        ),

        // 3) Inyectamos el repo en el ViewModel de "Listado de Clientes"
        ChangeNotifierProvider<ListaClientesViewModel>(
          create: (ctx) =>
              ListaClientesViewModel(ctx.read<ClienteRepository>()),
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
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
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
