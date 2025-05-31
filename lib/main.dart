// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import 'data/datasources/cliente_datasource.dart';
import 'repositories/cliente_repository.dart';
import 'viewmodels/cliente_nuevo_viewmodel.dart';
import 'viewmodels/lista_clientes_viewmodel.dart';
import 'viewmodels/clientes_pendientes_viewmodel.dart';
import 'viewmodels/tarjeta_cliente_viewmodel.dart';
import 'viewmodels/clientes_cercanos_viewmodel.dart';

import 'screens/splash.dart';
import 'screens/main_menu/main_menu_screen.dart';
import 'screens/lista_de_clientes/lista_de_clientes_screen.dart';
import 'screens/cliente_nuevo/cliente_nuevo_screen.dart';
import 'screens/cliente_pendiente/clientes_pendientes_screen.dart';
import 'screens/tarjeta_cliente/tarjeta_cliente_screen.dart';
import 'screens/clientes_cercanos/clientes_cercanos_screen.dart';
import 'screens/agregar_gastos/agregar_gastos_screen.dart';
import 'screens/reportes/reportes_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
  ));

  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<ClienteDatasource>(
          create: (_) => SupabaseClienteDatasource(Supabase.instance.client),
        ),
        Provider<ClienteRepository>(
          create: (ctx) => ClienteRepositoryImpl(
            Supabase.instance.client,
            ctx.read<ClienteDatasource>(),
          ),
        ),
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
        ChangeNotifierProvider(
          create: (ctx) =>
              TarjetaClienteViewModel(ctx.read<ClienteRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ClientesCercanosViewModel(ctx
              .read<ClienteRepository>()), // AGREGA EL NUEVO VIEWMODEL PROVIDER
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
        '/clientes_cercanos': (_) => const ClientesCercanosScreen(),
        '/agregar_gastos': (_) => const AgregarGastosScreen(),
        '/reportes': (_) => const ReportesScreen(),

        // Ahora la ruta detalle toma el clienteId de los argumentos:
        '/detalle': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments;
          if (args is int) {
            return TarjetaClienteScreen(clienteId: args);
          }
          // En caso de que no venga un int, mostramos un error o fallback:
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(child: Text('ID de cliente inválido')),
          );
        },
      },
      theme: ThemeData.light().copyWith(
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
      ),
    );
  }
}
