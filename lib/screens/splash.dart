import 'package:flutter/material.dart';
import 'main_menu/main_menu_screen.dart';
import '../main.dart'; // Para acceder a appConfig

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MainMenuScreen(),
        ),
      );
    });
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
            if (appConfig != null && appConfig!['cobrador_nombre'] != 'PLACEHOLDER_NOMBRE')
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                  'Bienvenido ${appConfig!['cobrador_nombre']}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
