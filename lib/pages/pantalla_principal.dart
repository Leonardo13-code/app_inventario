// lib/pages/pantalla_principal.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:InVen/services/auth_service.dart';

// Importa todas tus páginas de navegación
import 'package:InVen/pages/productos_page.dart';
import 'package:InVen/pages/historial_page.dart';
import 'package:InVen/pages/moneda_page.dart';
import 'package:InVen/pages/entrada_page.dart';
import 'package:InVen/pages/gestion_productos_page.dart';
import 'package:InVen/pages/salida_page.dart';
import 'package:InVen/pages/costos_page.dart';
import 'package:InVen/pages/venta_page.dart';
import 'package:InVen/pages/historial_ventas_page.dart';

// Definición del color primario (Debe coincidir con main.dart)
const Color invenPrimaryColor = Color(0xFF00508C);

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final AuthService _authService = AuthService();
  // Obtener el email del usuario para mostrarlo en el Drawer
  final String _userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Usuario no logueado';

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (mounted) {
        // La navegación se maneja en AuthGate al detectar el cambio de estado de usuario
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  // Lista de opciones del menú
  final List<Map<String, dynamic>> menuOptions = [
    // ... (Tu lista de opciones permanece igual)
    {'title': 'Vender', 'subtitle': 'Realiza ventas rápidas y registra pedidos.', 'icon': Icons.point_of_sale, 'color': Colors.green, 'page': const VentaPage()},
    {'title': 'Historial Ventas', 'subtitle': 'Revisa y reimprime tus facturas de venta.', 'icon': Icons.receipt_long, 'color': Colors.deepPurple, 'page': const HistorialVentasPage()},
    {'title': 'Gestionar', 'subtitle': 'Añade, edita o elimina productos del inventario.', 'icon': Icons.settings, 'color': Colors.teal.shade700, 'page': const GestionProductosPage()},
    {'title': 'Ver Stock', 'subtitle': 'Revisa el inventario actual de productos.', 'icon': Icons.inventory, 'color': Colors.blueGrey, 'page': const ProductosPage()},
    {'title': 'Entrada Stock', 'subtitle': 'Registra entradas de inventario o compras.', 'icon': Icons.add_shopping_cart, 'color': Colors.green.shade700, 'page': const EntradaPage()},
    {'title': 'Salida Stock', 'subtitle': 'Registra salidas por mermas o daños.', 'icon': Icons.remove_shopping_cart, 'color': Colors.red.shade700, 'page': const SalidaPage()},
    {'title': 'Historial Mov.', 'subtitle': 'Consulta todas las entradas y salidas de stock.', 'icon': Icons.history, 'color': Colors.amber.shade700, 'page': const HistorialPage()},
    {'title': 'Tasa Moneda', 'subtitle': 'Establece la tasa de cambio Bolívar/Dólar.', 'icon': Icons.monetization_on, 'color': Colors.orange.shade700, 'page': const MonedaPage()},
    {'title': 'Reporte Costos', 'subtitle': 'Revisa el costo de tu inventario total.', 'icon': Icons.bar_chart, 'color': Colors.brown.shade700, 'page': const CostosPage()},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // REEMPLAZAMOS EL TÍTULO DE TEXTO POR EL LOGO COMPLETO
        title: Image.asset(
          'assets/images/logo/icon_static.jpeg', // Logo InVen
          height: 50, 
        ),
        // Gracias al tema global, el fondo es invenPrimaryColor y el ícono es blanco
      ),
      
      // IMPLEMENTACIÓN DEL DRAWER CON MARCA
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // 1. DrawerHeader personalizado con el logo
            Container(
              decoration: const BoxDecoration(
                color: invenPrimaryColor, // Usamos el color de marca
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0, bottom: 20.0, left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ícono estático de InVen para un toque visual
                    Image.asset(
                      'assets/images/logo/icon_static.jpeg',
                      height: 70,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'InVen', // El nombre de la aplicación
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail, // Email del usuario logueado
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Opción de Cerrar Sesión
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: _logout,
            ),
            
            const Divider(),

            // 3. Títulos para cada grupo de páginas
            _buildDrawerSectionTitle('Gestión de Inventario'),
            
            // Replicamos las opciones para que aparezcan en el Drawer
            _buildDrawerItem(menuOptions[1]), // Entrada
            _buildDrawerItem(menuOptions[2]), // Salida
            _buildDrawerItem(menuOptions[3]), // Gestionar
            _buildDrawerItem(menuOptions[4]), // Ver Stock
            
            const Divider(),
            
            _buildDrawerSectionTitle('Ventas y Reportes'),
            _buildDrawerItem(menuOptions[0]), // Vender
            _buildDrawerItem(menuOptions[5]), // Historial Mov.
            _buildDrawerItem(menuOptions[6]), // Historial Ventas
            _buildDrawerItem(menuOptions[7]), // Tasa Moneda
            _buildDrawerItem(menuOptions[8]), // Reporte Costos
          ],
        ),
      ),
      
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (El resto del cuerpo permanece igual)
            
            const Text(
              'Bienvenido a InVen', // Título de bienvenida actualizado
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: invenPrimaryColor),
            ),
            const Text(
              'Selecciona una opción para empezar:',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            
            const Divider(height: 20, thickness: 1, color: Colors.black12),
            
            // --- GRID VIEW DE LAS TARJETAS DE ACCESO ---\r\n
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: menuOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, 
                crossAxisSpacing: 14.0, 
                mainAxisSpacing: 14.0,  
                childAspectRatio: 1.1, 
              ),
              itemBuilder: (context, index) {
                final option = menuOptions[index];
                return _buildAccessCard(
                  title: option['title'],
                  icon: option['icon'],
                  color: option['color'],
                  subtitle: option['subtitle'],
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
    );
  }
  
  // Widget auxiliar para las secciones del Drawer
  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
      child: Text(
        title,
        style: TextStyle(
          color: invenPrimaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
  
  // Widget auxiliar para los elementos del Drawer
  Widget _buildDrawerItem(Map<String, dynamic> option) {
    return ListTile(
      leading: Icon(option['icon'], color: option['color']),
      title: Text(option['title']),
      onTap: () {
        Navigator.pop(context); // Cierra el drawer
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => option['page']),
        );
      },
    );
  }

  // Tu widget auxiliar para las tarjetas (reconstruido con subtitle)
  Widget _buildAccessCard({
    required String title,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {

    final Color invenColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12), // Bordes menos redondeados
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Fondo blanco para un estilo limpio
          // Borde sutil para que la tarjeta destaque sobre el fondo
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            // Sombra muy sutil para dar efecto 3D moderno
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0), 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ÍCONO: Mantiene el color vibrante original
              Icon(icon, size: 36, color: color), 
              const SizedBox(height: 12), 
              
              // 2. TÍTULO: Usamos un color oscuro (o InVen Primary Color)
              Text(
                title,
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: invenColor, // Color de InVen para el título
                ),
              ),
              const SizedBox(height: 4),
              
              // 3. SUBTÍTULO: Texto en gris sutil
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11, 
                  color: Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis, 
                maxLines: 2, 
              ),
            ],
          ),
        ),
      ),
    );
  }
}