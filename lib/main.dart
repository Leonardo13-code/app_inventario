import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_inventario/auth/auth_gate.dart';
import 'package:app_inventario/firebase_options.dart'; // Importa las opciones generadas por FlutterFire
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asegura la inicialización del motor de Flutter

  // Inicializa Firebase usando las opciones para la plataforma actual
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
      title: 'Inventario App',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const AuthGate(),
            supportedLocales: const [
        Locale('en', 'US'), // Inglés
        Locale('es', 'ES'), // Español
        // Puedes agregar más si es necesario
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}