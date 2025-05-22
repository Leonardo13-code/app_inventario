// lib/pages/pantalla_principal.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Mantener para el user.email
import 'package:app_inventario/services/auth_service.dart'; // Importar el servicio de autenticación
import 'package:app_inventario/pages/productos_page.dart';
import 'package:app_inventario/pages/historial_page.dart';
import 'package:app_inventario/pages/moneda_page.dart';
import 'package:app_inventario/pages/entrada_page.dart';
// Importa la página de Salida una vez que la crees
// import 'package:app_inventario/pages/salida_page.dart';

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
        // No es necesario un SnackBar aquí, AuthGate ya se encargará de la navegación.
        // Opcionalmente, puedes mantener el SnackBar para confirmación visual inmediata.
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
                      icon: Icons.remove_shopping_cart,
                      title: "Salidas",
                      subtitle: "Registrar ventas o retiros",
                      color: Colors.redAccent,
                      onTap: () {
                        // Implementar SalidaPage
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(builder: (_) => const SalidaPage()),
                        // );
                         ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Funcionalidad de Salidas en desarrollo.")),
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
                      subtitle: "Calcular y analizar",
                      color: Colors.brown,
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Funcionalidad de Costos en desarrollo.")),
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
          // Aquí podríamos añadir información resumida del inventario
          // Por ejemplo:
          // _buildSummaryCard(
          //   icon: Icons.storage,
          //   title: "Productos en Stock",
          //   value: "250", // Esto debería venir de Firestore
          //   color: Colors.blue.shade200,
          // ),
          // const SizedBox(height: 10),
          // _buildSummaryCard(
          //   icon: Icons.warning_amber,
          //   title: "Stock Bajo",
          //   value: "5", // Esto debería venir de Firestore
          //   color: Colors.red.shade200,
          // ),
        ],
      ),
    );
  }

  // Comentado temporalmente porque no se usa aún. Lo activaremos al conectar con datos de inventario.
  /*
  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.white),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  */

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
              colors: [color.withAlpha((255 * 0.8).round()), color], // Corregido withOpacity
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 48, color: Colors.white),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}