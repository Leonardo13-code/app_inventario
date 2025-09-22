// lib/pages/pantalla_principal.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Mantener para el user.email
import 'package:app_inventario/services/auth_service.dart'; // Importar el servicio de autenticación
import 'package:app_inventario/pages/productos_page.dart';
import 'package:app_inventario/pages/historial_page.dart';
import 'package:app_inventario/pages/moneda_page.dart';
import 'package:app_inventario/pages/entrada_page.dart';
import 'package:app_inventario/pages/gestion_productos_page.dart';
import 'package:app_inventario/pages/salida_page.dart';
import 'package:app_inventario/pages/costos_page.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final AuthService _authService = AuthService(); // Instancia del servicio de autenticación

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        // Redireccionar al AuthGate que manejará el estado de autenticación
        // y mostrará LoginPage si no hay usuario.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sesión cerrada correctamente.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cerrar sesión: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inventario App',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.teal, // Color de la barra de app
        elevation: 0, // Sin sombra
        actions: [
          IconButton(
            onPressed: _logout, // Usar el método del servicio
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal,
              Colors.tealAccent,
            ],
          ),
        ),
        child: Column(
          children: [
            // Sección de Bienvenida e Información Resumida (Placeholder por ahora)
            _buildWelcomeSection(),
            // Cuadrícula de Opciones de Menú
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildMenuItem(
                      context,
                      icon: Icons.inventory_2,
                      title: "Productos",
                      subtitle: "Ver stock actual",
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProductosPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.add_shopping_cart,
                      title: "Entradas",
                      subtitle: "Registrar nuevos productos",
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EntradaPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.remove_shopping_cart, // Ícono para salida
                      title: "Salidas",
                      subtitle: "Registrar salida de productos", // Nuevo subtítulo
                      color: Colors.red, // Color para salidas
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SalidaPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: "Historial",
                      subtitle: "Ver movimientos recientes",
                      color: Colors.orangeAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HistorialPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.attach_money,
                      title: "Moneda",
                      subtitle: "Convertir y gestionar tasas",
                      color: Colors.purpleAccent,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MonedaPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.calculate,
                      title: "Costos",
                      subtitle: "Calcular el costo del inventario", // Nuevo subtítulo
                      color: Colors.blueGrey, // Nuevo color
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CostosPage()),
                        );
                      },
                    ),
                    _buildMenuItem(
                      context,
                      icon: Icons.add_box_outlined, // Un icono que sugiera "crear" o "gestionar" un elemento
                      title: "Gestionar Productos",
                      subtitle: "Crear o editar artículos",
                      color: Colors.purple, // Un color distinto para esta sección
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GestionProductosPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widgets Auxiliares para la Interfaz ---

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.teal.shade700,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Hola,",
            style: TextStyle(
              fontSize: 20,
              color: Colors.white70,
            ),
          ),
          Text(
            FirebaseAuth.instance.currentUser?.email ?? "Usuario", // Muestra el correo o "Usuario"
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white, // Color de fondo de la tarjeta
        elevation: 6, // Sombra más pronunciada
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withAlpha((255 * 0.8).round()), color],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0), // Ajuste de padding de 16.0 a 12.0
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 40, color: Colors.white), // Tamaño del icono ajustado de 48 a 40
                const SizedBox(height: 8), // Ajuste de espacio de 10 a 8
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16, // Ajuste de tamaño de fuente de 18 a 16
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11, // Ajuste de tamaño de fuente de 12 a 11
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis, // Asegurar que el texto largo se trunca
                  maxLines: 2, // Permitir hasta 2 líneas para el subtítulo
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}