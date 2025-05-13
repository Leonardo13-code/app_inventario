import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';
import 'auth_gate.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para inicializar Firebase
  await Firebase.initializeApp(); // Inicia Firebase antes de que la app arranque
  runApp(const MyApp()); // Lanza tu app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Quita la etiqueta de debug
      title: 'Inventario App',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const AuthGate(), // Pantalla principal dependera de si esta autenticado o no
    );
  }
}
