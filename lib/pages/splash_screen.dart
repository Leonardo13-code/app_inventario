// lib/pages/splash_screen.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:InVen/auth/auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _logoOpacity = 0.0; 

  @override
  void initState() {
    super.initState();
    // Inicia la animación de fundido (fade-in)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _logoOpacity = 1.0; 
      });
    });

    // Navega a la pantalla de autenticación
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()), 
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      body: Center(
        child: AnimatedOpacity(
          opacity: _logoOpacity,
          duration: const Duration(milliseconds: 2000), // 2 segundos de duración del fundido
          curve: Curves.easeIn, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Carga el logo (solo icono)
              Image.asset(
                'assets/images/logo/logo_light.jpeg',
                height: 500,

              ),
            ],
          ),
        ),
      ),
    );
  }
}