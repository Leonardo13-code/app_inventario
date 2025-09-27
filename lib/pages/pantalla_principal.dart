// lib/pages/pantalla_principal.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:app_inventario/services/auth_service.dart'; 

// Importa todas tus páginas de navegación
import 'package:app_inventario/pages/productos_page.dart';
import 'package:app_inventario/pages/historial_page.dart';
import 'package:app_inventario/pages/moneda_page.dart';
import 'package:app_inventario/pages/entrada_page.dart';
import 'package:app_inventario/pages/gestion_productos_page.dart';
import 'package:app_inventario/pages/salida_page.dart';
import 'package:app_inventario/pages/costos_page.dart';
import 'package:app_inventario/pages/venta_page.dart';
import 'package:app_inventario/pages/historial_ventas_page.dart';
// ¡Asegúrate de que tus imports estén completos!

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final AuthService _authService = AuthService();
  final String _userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Usuario';

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  // --- NUEVO WIDGET AUXILIAR: Tarjeta de Acceso Minimalista ---
  Widget _buildAccessCard({
    required String title,
    required IconData icon,
    required Color color, // Usaremos este color como acento
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3, // Sombra suave para darle un aspecto de tarjeta
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color), // Ícono con color de acento
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF212529), // Texto oscuro
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Definición de las opciones de menú agrupadas
    final List<Map<String, dynamic>> menuOptions = [
      // 1. GESTIÓN E INVENTARIO
      {'title': 'Inventario', 'page': const ProductosPage(), 'icon': Icons.inventory, 'color': const Color(0xFF1976D2)},
      {'title': 'Gestionar Productos', 'page': const GestionProductosPage(), 'icon': Icons.category, 'color': Colors.purple},
      {'title': 'Cálculo de Costos', 'page': const CostosPage(), 'icon': Icons.account_tree, 'color': Colors.teal},
      // 2. MOVIMIENTOS
      {'title': 'Registrar Entrada', 'page': const EntradaPage(), 'icon': Icons.arrow_downward, 'color': const Color(0xFF388E3C)},
      {'title': 'Registrar Salida', 'page': const SalidaPage(), 'icon': Icons.arrow_upward, 'color': const Color(0xFFD32F2F)},
      {'title': 'Historial Movimientos', 'page': const HistorialPage(), 'icon': Icons.history, 'color': Colors.orange},
      // 3. VENTAS Y FINANZAS
      {'title': 'Registrar Venta', 'page': const VentaPage(), 'icon': Icons.shopping_cart, 'color': Colors.pink},
      {'title': 'Historial de Ventas', 'page': const HistorialVentasPage(), 'icon': Icons.receipt, 'color': Colors.indigo},
      {'title': 'Conversor Moneda', 'page': const MonedaPage(), 'icon': Icons.monetization_on, 'color': Colors.brown},
    ];

    // Usaremos un fondo blanco/gris muy claro para el minimalismo
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Fondo Gris Muy Claro
      appBar: AppBar(
        title: const Text(
          'INVENTARIO APP',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1976D2), // Color de Acción
        elevation: 0, // Eliminar la sombra de la barra
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BIENVENIDA / TARJETA DE USUARIO ---
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFF1976D2)),
                  title: const Text('Bienvenido', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_userEmail),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // --- TÍTULO DE SECCIÓN DE MÓDULOS ---
              const Text(
                'Módulos de Acceso Rápido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212529),
                ),
              ),
              
              const Divider(height: 20, thickness: 1, color: Colors.black12),
              
              // --- GRID VIEW DE LAS TARJETAS DE ACCESO ---
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: menuOptions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 columnas
                  crossAxisSpacing: 12.0, // Espacio horizontal generoso
                  mainAxisSpacing: 12.0,  // Espacio vertical generoso
                  childAspectRatio: 1.3, // Controla la altura de las tarjetas
                ),
                itemBuilder: (context, index) {
                  final option = menuOptions[index];
                  return _buildAccessCard(
                    title: option['title'],
                    icon: option['icon'],
                    color: option['color'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => option['page']),
                      );
                    },
                  );
                },
              ),
              
              const SizedBox(height: 30),
              
              // Aquí podrías añadir un pie de página o un indicador de versión si lo deseas.
            ],
          ),
        ),
      ),
    );
  }
}