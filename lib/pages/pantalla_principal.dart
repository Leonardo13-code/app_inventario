// lib/pages/pantalla_principal.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:InVen/services/auth_service.dart';
import 'package:InVen/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Páginas de navegación
import 'package:InVen/pages/productos_page.dart';
import 'package:InVen/pages/historial_page.dart';
import 'package:InVen/pages/moneda_page.dart';
import 'package:InVen/pages/entrada_page.dart';
import 'package:InVen/pages/gestion_productos_page.dart';
import 'package:InVen/pages/salida_page.dart';
import 'package:InVen/pages/costos_page.dart';
import 'package:InVen/pages/venta_page.dart';
import 'package:InVen/pages/historial_ventas_page.dart';
import 'package:InVen/pages/configuracion_page.dart';

// Color primario de InVen
const Color invenPrimaryColor = Color(0xFF00508C);

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

// --- CLASE AUXILIAR PARA EL ANÁLISIS ---
class SalesAnalysis {
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> bottomProducts;

  SalesAnalysis(this.topProducts, this.bottomProducts);
}

// --- CLASE AUXILIAR PARA LOS MÓDULOS ---
class Module {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;

  Module({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });
}

// Clase para encapsular los datos de la alerta
class LowStockData {
  final List<String> lowStockProducts;
  final int umbral;

  LowStockData(this.lowStockProducts, this.umbral);
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService(); // Instancia del servicio
  final String _userEmail = FirebaseAuth.instance.currentUser?.email ?? 'Usuario InVen';

    // Umbral de stock bajo
  final int _defaultStockUmbral = 10;
  int _currentStockUmbral = 10; 
  late Future<LowStockData> _lowStockFuture; 

  @override
    void initState() {
      super.initState();
      // 1. Inicializa el Future para la alerta
      _lowStockFuture = _getLowStockProducts(); 
      // 2. Carga el umbral actual para las métricas del encabezado
      _loadStockUmbral();
    }

  // Método para cargar el umbral actual desde SharedPreferences
  Future<void> _loadStockUmbral() async {
    final prefs = await SharedPreferences.getInstance();
    final int umbral = prefs.getInt('stock_bajo_umbral') ?? _defaultStockUmbral;
    if (mounted) {
      setState(() {
        _currentStockUmbral = umbral;
      });
    }
  }

  // Método para refrescar el Future y el estado al volver de la Configuración
  void _refreshDashboard() {
    setState(() {
      _lowStockFuture = _getLowStockProducts();
      _loadStockUmbral();
    });
  }

  void _mostrarDialogoCierreSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas salir de InVen?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cerrar diálogo
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar diálogo
                await _authService.signOut(); // Cerrar sesión real
              },
              child: const Text('Salir', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }


  // Lógica para obtener productos con stock bajo
  Future<LowStockData> _getLowStockProducts() async {
      final prefs = await SharedPreferences.getInstance();
      final int umbral = prefs.getInt('stock_bajo_umbral') ?? _defaultStockUmbral; 
      
      final productosSnapshot = await _firestoreService.getCollectionOnce('productos');
      List<String> lowStockNames = [];
      
      for (var doc in productosSnapshot.docs) {
        final data = doc.data();
        final stock = (data['stock'] as num?)?.toDouble() ?? 0.0;
        final nombre = data['nombre'] as String? ?? 'Producto Desconocido';
        
        if (stock > 0 && stock <= umbral) { 
          lowStockNames.add('$nombre (${stock.toStringAsFixed(stock.remainder(1) == 0 ? 0 : 2)})');
        }
      }
      return LowStockData(lowStockNames, umbral); 
  }

  // Lista completa de módulos de la aplicación
  final List<Module> _modules = [
    Module(
      title: 'Ventas',
      subtitle: 'Registra nuevas ventas y genera facturas al instante.',
      icon: Icons.point_of_sale,
      color: Colors.green.shade700,
      page: const VentaPage(),
    ),
    Module(
      title: 'Historial Ventas',
      subtitle: 'Consulta y reimprime todas las facturas de ventas.',
      icon: Icons.receipt_long,
      color: Colors.cyan.shade700,
      page: const HistorialVentasPage(),
    ),
    Module(
      title: 'Inventario',
      subtitle: 'Consulta el stock y los detalles de cada producto.',
      icon: Icons.inventory_2_outlined,
      color: Colors.blue.shade700,
      page: const ProductosPage(),
    ),
    Module(
      title: 'Gestión Prod.',
      subtitle: 'Crea, edita y elimina productos del sistema.',
      icon: Icons.settings,
      color: Colors.purple.shade700,
      page: const GestionProductosPage(),
    ),
    Module(
      title: 'Entradas',
      subtitle: 'Añade existencias nuevas al inventario.',
      icon: Icons.shopping_cart_checkout,
      color: Colors.orange.shade700,
      page: const EntradaPage(),
    ),
    Module(
      title: 'Salidas',
      subtitle: 'Registra la salida de productos por diversos motivos.',
      icon: Icons.remove_shopping_cart,
      color: Colors.red.shade700,
      page: const SalidaPage(),
    ),
    Module(
      title: 'Historial Mov.',
      subtitle: 'Revisa todos los movimientos de entrada y salida.',
      icon: Icons.history,
      color: Colors.brown.shade700,
      page: const HistorialPage(),
    ),
    Module(
      title: 'Cálculo de Costos',
      subtitle: 'Visualiza el Costo Promedio Ponderado por producto.',
      icon: Icons.attach_money,
      color: Colors.teal.shade700,
      page: const CostosPage(),
    ),
    Module(
      title: 'Tasa de Cambio',
      subtitle: 'Consulta la tasa actual y realiza conversiones.',
      icon: Icons.calculate,
      color: Colors.amber.shade700,
      page: const MonedaPage(),
    ),
  ];

  void _navigateToPage(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  // --- WIDGET DE TARJETA ---
  Widget _buildModuleCard(Module module) {
    const Color invenColor = invenPrimaryColor;

    return InkWell(
      onTap: () => _navigateToPage(context, module.page),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(module.icon, size: 32, color: module.color),
              const SizedBox(height: 8),
              Text(
                module.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: invenColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                module.subtitle,
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

  // === AGREGACIÓN DE DATOS DE VENTAS ===
  Future<SalesAnalysis> _getSalesAnalysis({DateTime? startDate}) async {
    // 1. Obtener todos los productos para mapear ID a Nombre
    final productosSnapshot = await _firestoreService.getCollectionOnce('productos');
    final Map<String, String> productNames = {};
    productosSnapshot.docs.forEach((doc) {
      productNames[doc.id] = doc.data()['nombre'] as String? ?? 'Producto Desconocido';
    });

    // Obtenemos una referencia a la colección de ventas
    Query<Map<String, dynamic>> ventasQuery = FirebaseFirestore.instance.collection('ventas').withConverter<Map<String, dynamic>>(
      fromFirestore: (snapshot, _) => snapshot.data()!,
      toFirestore: (model, _) => model,
    );

    // Si se proporciona una fecha de inicio, agregamos el filtro 'where'
    if (startDate != null) {
      ventasQuery = ventasQuery.where('fecha', isGreaterThanOrEqualTo: startDate);
    }
    
    // Ejecutar la consulta
    final ventasSnapshot = await ventasQuery.get();
    
    Map<String, double> productSales = {};

    // 2. Obtener todas las ventas y sumar cantidades
    for (var ventaDoc in ventasSnapshot.docs) {
      final data = ventaDoc.data();
      // 'productos' es una lista de mapas dentro del documento de venta
      final List<dynamic> productosVendidos = data['productos'] as List<dynamic>? ?? []; 

      for (var item in productosVendidos) {
        final Map<String, dynamic> productItem = item as Map<String, dynamic>;
        final String productId = productItem['id'] as String? ?? '';
        final double cantidad = (productItem['cantidad'] as num?)?.toDouble() ?? 0.0;
        
        if (productId.isNotEmpty) {
          productSales.update(
            productId, 
            (existingCantidad) => existingCantidad + cantidad, 
            ifAbsent: () => cantidad,
          );
        }
      }
    }

    // 3. Crear lista de resultados
    List<Map<String, dynamic>> sortedProducts = productSales.entries.map((entry) {
      return {
        'nombre': productNames[entry.key] ?? 'Producto Desconocido',
        'cantidad': entry.value,
      };
    }).toList();
    
    // 4. Ordenar para obtener Top Sellers
    sortedProducts.sort((a, b) => (b['cantidad'] as double).compareTo(a['cantidad'] as double));

    final int limit = 5;
    final topProducts = sortedProducts.take(limit).toList();
    
    // 5. Determinar Worst Sellers (productos con ventas más bajas o 0)
    
    // Productos con 0 ventas (los más lentos de todo el inventario)
    List<Map<String, dynamic>> productsWithZeroSales = productNames.entries
        .where((entry) => !productSales.containsKey(entry.key))
        .map((entry) => {'nombre': entry.value, 'cantidad': 0.0})
        .toList();

    // Productos con ventas > 0, ordenados ascendentemente
    List<Map<String, dynamic>> productsWithSales = sortedProducts.where((p) => (p['cantidad'] as double) > 0).toList();
    List<Map<String, dynamic>> bottomProductsWithSales = productsWithSales.reversed.toList();
    
    List<Map<String, dynamic>> worstSelling = [];
    
    // Añadir primero los de 0 ventas
    worstSelling.addAll(productsWithZeroSales.take(limit));
    
    // Si quedan puestos, añadir los de ventas más bajas (> 0)
    if (worstSelling.length < limit) {
        int remaining = limit - worstSelling.length;
        worstSelling.addAll(bottomProductsWithSales.take(remaining));
    }
    
    return SalesAnalysis(topProducts, worstSelling);
  }

  // === WIDGET DE DASHBOARD ===
  Widget _buildDashboardHeader() {
    // Usaremos StreamBuilder para tiempo real.
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getCollection('productos').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LinearProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar métricas.'));
        }

        final productos = snapshot.data?.docs ?? [];
        
        // 1. CÁLCULO DE MÉTRICAS
        double valorTotalInventario = 0.0;
        int totalProductos = 0;
        int productosBajoStock = 0;

        for (var doc in productos) {
          final data = doc.data() as Map<String, dynamic>;
          final stock = (data['stock'] as num?)?.toDouble() ?? 0.0;
          final precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
          
          totalProductos++;
          valorTotalInventario += stock * precio;
          
          // Lógica para stock bajo
          if (stock > 0 && stock <= _currentStockUmbral) {
            productosBajoStock++;
          }
        }

        // 2. CREACIÓN DE LAS MÉTRICAS EN FORMATO VISUAL
        final metrics = [
          // Total de Productos
          {
            'title': 'Productos Activos',
            'value': totalProductos.toString(),
            'icon': Icons.category_outlined,
            'color': Colors.blue,
          },
          // Productos con Stock Bajo
          {
            'title': 'Stock Bajo',
            'value': productosBajoStock.toString(),
            'icon': Icons.warning_amber,
            // Rojo solo si hay productos con stock bajo
            'color': productosBajoStock > 0 ? Colors.red.shade700 : Colors.green, 
          },
          // Valor Total del Inventario (en USD)
          {
            'title': 'Valor Inventario',
            'value': NumberFormat.currency(locale: 'en_US', symbol: '\$').format(valorTotalInventario),
            'icon': Icons.monetization_on_outlined,
            'color': invenPrimaryColor,
          },
        ];

        // Usamos GridView dentro de un SingleChildScrollView para asegurar que sea responsivo
        // y se adapte al número de métricas en cualquier pantalla.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, top: 8.0),
              child: Text(
                'Tablero de Control Rápido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            GridView.builder(
              shrinkWrap: true, // Importante para usarlo dentro de un Column/ListView
              physics: const NeverScrollableScrollPhysics(), // Evita scroll anidado
              itemCount: metrics.length,
              // Similar al GridView de módulos, pero más pequeño para métricas
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180.0, 
                crossAxisSpacing: 10.0,
                mainAxisSpacing: 10.0,
                childAspectRatio: 1.6,
              ),
              itemBuilder: (context, index) {
                final metric = metrics[index];
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                metric['title'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metric['value'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: metric['color'] as Color,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Icon(metric['icon'] as IconData, size: 28, color: metric['color'] as Color),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 30, thickness: 1), // Separador visual
          ],
        );
      },
    );
  }

  // === WIDGET: ANÁLISIS DE VENTAS (MÁS/MENOS VENDIDOS) ===

  Widget _buildSalesAnalysisWidget() {
    // Definimos la fecha de inicio: 7 días antes de hoy
    final DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
    return FutureBuilder<SalesAnalysis>(
      future: _getSalesAnalysis(startDate: startDate),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error al cargar rendimiento de ventas.', style: TextStyle(color: Colors.red)));
        }
        
        if (!snapshot.hasData || (snapshot.data!.topProducts.isEmpty && snapshot.data!.bottomProducts.isEmpty)) {
          return const Padding(
            padding: EdgeInsets.only(top: 16.0),
            child: Text('No hay datos de ventas para mostrar.', style: TextStyle(fontStyle: FontStyle.italic)),
          );
        }

        final analysis = snapshot.data!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, top: 16.0),
              child: Text(
                'Rendimiento de Productos (Últimos 7 Días)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            
            // Layout para ser responsivo (lado a lado en escritorio, apilado en móvil)
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildProductListCard('Top 5 Ventas 🏆', analysis.topProducts, Colors.green.shade600, true)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildProductListCard('5 Ventas Bajas 📉', analysis.bottomProducts, Colors.red.shade700, false)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildProductListCard('Top 5 Ventas 🏆', analysis.topProducts, Colors.green.shade600, true),
                      const SizedBox(height: 16),
                      _buildProductListCard('5 Ventas Bajas 📉', analysis.bottomProducts, Colors.red.shade700, false),
                    ],
                  );
                }
              },
            ),
            const Divider(height: 30, thickness: 1), 
          ],
        );
      },
    );
  }

// === ADVERTENCIA DE STOCK BAJO ===
Widget _buildLowStockWarning() {
return FutureBuilder<LowStockData>( 
      future: _lowStockFuture, 
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink(); 
        }

        final data = snapshot.data!;
        final lowStockProducts = data.lowStockProducts;
        final umbral = data.umbral;
        
        if (lowStockProducts.isEmpty) {
          return const SizedBox.shrink();
        }

        // Si hay productos con stock bajo, mostrar la alerta
        return Card(
          margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          color: Colors.yellow.shade100,// Fondo amarillo clarito
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.red.shade300, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '🚨 ¡ALERTA CRÍTICA DE STOCK!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                        // Añadimos ellipsis por si acaso, aunque Expanded lo maneja
                        overflow: TextOverflow.ellipsis, 
                      ),
                    ),
                  ],
                ),
                const Divider(height: 15, color: Colors.redAccent),
                Text(
                  // Usamos la variable 'umbral' local, que viene del Future
                  'Los siguientes ${lowStockProducts.length} productos están por debajo del umbral de $umbral unidades:', 
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                // Mostrar un máximo de 5 productos
                ...lowStockProducts.take(5).map((productName) => 
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                    child: Text('• $productName', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  )
                ).toList(),
                
                if (lowStockProducts.length > 5)
                    Padding(
                        padding: const EdgeInsets.only(top: 4.0, left: 8.0),
                        child: Text('+ ${lowStockProducts.length - 5} productos más...', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                    ),

                const SizedBox(height: 15),
                // Botón para ir a la lista completa
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.inventory, size: 20),
                    label: const Text('Ir a Inventario'),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const ProductosPage())), 
                    style: OutlinedButton.styleFrom(
                      foregroundColor: invenPrimaryColor,
                      side: BorderSide(color: invenPrimaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
}

  // WIDGET AUXILIAR: Muestra la lista de 5 productos
  Widget _buildProductListCard(
    String title, 
    List<Map<String, dynamic>> products, 
    Color headerColor, 
    bool isTop
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: headerColor,
              ),
            ),
            const Divider(height: 12, thickness: 1),
            if (products.isEmpty)
              const Text('No hay datos disponibles.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final name = product['nombre'] as String;
              // Formatear cantidad para no mostrar decimales si es un número entero
              final quantity = (product['cantidad'] as double).toStringAsFixed(0);
              
              // Iconos y colores para ranking
              IconData icon = isTop ? Icons.trending_up : Icons.trending_down;
              Color iconColor = headerColor;
              
              if (isTop && index < 3) {
                icon = index == 0 ? Icons.star : (index == 1 ? Icons.star_half : Icons.star_border);
                iconColor = index == 0 ? Colors.amber.shade700 : (index == 1 ? Colors.grey.shade500 : Colors.brown.shade400);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$quantity und.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isTop ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('InVen', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      drawer: _buildDrawer(context),
      
// Usamos ListView para poder tener el Header y el GridView
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HEADER DE MÉTRICAS PROFESIONAL
              _buildDashboardHeader(),

              // 2. WIDGET DE ADVERTENCIA DE STOCK BAJO CLIENTE-SIDE
              _buildLowStockWarning(),

              // 3. WIDGET DE ANÁLISIS DE VENTAS (MÁS/MENOS VENDIDOS)
              _buildSalesAnalysisWidget(),

              // 4. TÍTULO PARA LOS MÓDULOS
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Módulos de Navegación',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              // 5. GRIDVIEW RESPONSIVO DE MÓDULOS
              GridView.builder(
                shrinkWrap: true, // ¡Importante! Hace que ocupe solo el espacio necesario.
                physics: const NeverScrollableScrollPhysics(), // Deshabilita su propio scroll
                itemCount: _modules.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320.0, 
                  crossAxisSpacing: 16.0, 
                  mainAxisSpacing: 16.0, 
                  childAspectRatio: 1.4, 
                ),
                itemBuilder: (context, index) {
                  return _buildModuleCard(_modules[index]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Widget del Drawer
  Widget _buildDrawer(BuildContext context) {
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            // Header del Drawer
            UserAccountsDrawerHeader(
              accountName: const Text("InVen Admin"),
              accountEmail: Text(_userEmail),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: invenPrimaryColor),
              ),
              decoration: const BoxDecoration(
                color: invenPrimaryColor,
              ),
            ),
            
            // Enlace de Inicio
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
              },
            ),

            const Divider(),
            
            const Padding(
              padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
              child: Text(
                'Módulos del Sistema',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: invenPrimaryColor,
                ),
              ),
            ),

            // Generar los ListTiles para cada módulo
            ..._modules.map((module) {
              return ListTile(
                leading: Icon(module.icon, color: module.color), // Usamos el color del módulo
                title: Text(module.title),
                onTap: () {
                  Navigator.pop(context); // Cierra el drawer primero
                  _navigateToPage(context, module.page); // Navega a la página
                },
              );
            }),
            
            const Divider(),

            // Item de Configuración
            ListTile(
              leading: const Icon(Icons.settings, color: invenPrimaryColor),
              title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ConfiguracionPage()), 
                );
                // Llama al refresco del dashboard para actualizar la alerta
                _refreshDashboard(); 
              },
            ),


            ListTile(
              leading: const Icon(Icons.info_outline, color: invenPrimaryColor),
              title: const Text('Acerca de', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'InVen',
                  applicationVersion: 'Versión 1.0.0',
                  applicationLegalese: '© 2025 InVen - Desarrolladores Leonardo Barreto & Stefany Barreto |\nProyecto de Grado - Ingeniería en Informática UPTT',
                  applicationIcon: const Icon(Icons.inventory_2, size: 50, color: invenPrimaryColor),
                  children: [
                    const SizedBox(height: 20),
                    const Text('Sistema de Gestión de Inventario, Ventas y Facturación desarrollado con Flutter y Firebase.'),
                    const SizedBox(height: 10),
                    const Text('Características:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('• Control de Stock en tiempo real'),
                    const Text('• Manejo de ventas de productos'),
                    const Text('• Facturación PDF multimoneda'),
                    const Text('• Tasa BCV automática y manual'),
                    const Text('• Cálculo de Costos (CAPP)'),
                  ],
                );
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Cierra el drawer
                _mostrarDialogoCierreSesion(context);
              },
            ),
          ],
        ),
      );
    }
  }