// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:InVen/firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Importa la nueva pantalla de carga. Asegúrate de que la ruta sea correcta.
import 'package:InVen/pages/splash_screen.dart';

// 1. DEFINICIÓN DEL COLOR PRIMARIO DE INVEN (Deep Blue #00508C)
const Color invenPrimaryColor = Color(0xFF00508C); 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InVen', // Nombre de la aplicación
      
      // 2. APLICACIÓN DEL TEMA GENERAL
      theme: ThemeData(
        useMaterial3: true,
        // Paleta de colores principal de InVen
        colorScheme: ColorScheme.fromSeed(
          seedColor: invenPrimaryColor,
          primary: invenPrimaryColor,
          secondary: Colors.amber, // Un color secundario, puedes ajustarlo
        ),
        // Estilo de los AppBars global (Títulos y botones usan este color por defecto)
        appBarTheme: const AppBarTheme(
          backgroundColor: invenPrimaryColor,
          foregroundColor: Colors.white, // Color de iconos y texto
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        // Estilo de botones elevados para la marca
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: invenPrimaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      
      // 3. HOME AHORA ES LA PANTALLA DE CARGA
      home: const SplashScreen(), 
      
      supportedLocales: const [
        Locale('en', 'US'), 
        Locale('es', 'ES'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}