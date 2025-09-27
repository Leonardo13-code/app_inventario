// lib/pages/costos_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_inventario/services/firestore_service.dart';

class CostosPage extends StatefulWidget {
  const CostosPage({super.key});

  @override
  State<CostosPage> createState() => CostosPageState();
}

class CostosPageState extends State<CostosPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  Map<String, double> _costosPromedio = {};
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = ''; // Variable para almacenar la consulta de búsqueda

  @override
  void initState() {
    super.initState();
    _calcularCostosPromedio();
    // Escuchar cambios en la barra de búsqueda
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _calcularCostosPromedio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Map<String, List<Map<String, dynamic>>> productMovements = {};

      // 1. Obtener todos los movimientos de entrada
      final querySnapshot = await _firestoreService.getCollectionOnce('movimientos');
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data(); 

        final String? productoIdNullable = data['productoId'];
        final String? tipoNullable = data['tipo'];

        if (productoIdNullable == null) {
          print('Advertencia: Documento de movimiento ${doc.id} tiene productoId nulo. Saltando.');
          continue; 
        }
        final String productoId = productoIdNullable; 
        final String tipo = tipoNullable ?? ''; 

        // --- CORRECCIÓN 1: Cargar 'cantidad' como double ---
        final double cantidad = (data['cantidad'] is num ? (data['cantidad'] as num).abs().toDouble() : 0.0); 
        final double costoUnitario = (data['costoUnitario'] as num?)?.toDouble() ?? 0.0; 

        if (!productMovements.containsKey(productoId)) {
          productMovements[productoId] = [];
        }
        productMovements[productoId]!.add({
          'tipo': tipo,
          'cantidad': cantidad, // Cantidad ahora es double
          'costoUnitario': costoUnitario,
        });
      }

      final Map<String, double> calculatedCosts = {};

      // 2. Calcular el costo promedio ponderado para cada producto
      for (var productId in productMovements.keys) {
        final List<Map<String, dynamic>> movements = productMovements[productId]!;
        
        double totalCost = 0.0;
        double totalQuantity = 0.0; // CORRECCIÓN 2: Total Quantity ahora es double

        for (var movement in movements) {
          if (movement['tipo'] == 'Entrada') {
            // Asegurarse de que 'cantidad' sea double para la suma y multiplicación
            final double movementCantidad = (movement['cantidad'] is num ? (movement['cantidad'] as num).toDouble() : 0.0);
            final double movementCostoUnitario = (movement['costoUnitario'] is num ? (movement['costoUnitario'] as num).toDouble() : 0.0);

            totalCost += (movementCantidad * movementCostoUnitario);
            totalQuantity += movementCantidad; // Suma de cantidades (que pueden ser decimales)
          }
        }
        
        if (totalQuantity > 0.0) { // Compara con 0.0
          final double capp = totalCost / totalQuantity;
          calculatedCosts[productId] = capp;
        } else {
          calculatedCosts[productId] = 0.0; 
        }
      }

      if (mounted) {
        setState(() {
          _costosPromedio = calculatedCosts;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al calcular costos: ${e.toString()}';
          print('Error en _calcularCostosPromedio: $e'); 
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Costos de Inventario',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator( 
              onRefresh: _calcularCostosPromedio,
              child: _errorMessage != null
                  ? Center( 
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                            const SizedBox(height: 10),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.red[700]),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _calcularCostosPromedio,
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column( // Envolver el StreamBuilder y la barra de búsqueda
                      children: [
                        // --- CORRECCIÓN 3: Barra de Búsqueda ---
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              labelText: 'Buscar producto',
                              suffixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(15.0)),
                              ),
                            ),
                          ),
                        ),
                        
                        Expanded(
                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(child: Text('Error al cargar productos: ${snapshot.error}'));
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              final allProducts = snapshot.data?.docs ?? [];
                              
                              // Filtrar productos por la barra de búsqueda
                              final filteredProducts = allProducts.where((doc) {
                                final data = doc.data();
                                final nombre = data['nombre']?.toString().toLowerCase() ?? '';
                                return nombre.contains(_searchQuery.toLowerCase());
                              }).toList();


                              if (allProducts.isEmpty) {
                                // ... (Manejo de productos vacíos, sin cambios)
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inventory_2, size: 80, color: Colors.grey[400]),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No hay productos registrados.',
                                        style: TextStyle(fontSize: 18, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Calcular el costo total del inventario solo de los productos filtrados
                              double costoTotalInventario = 0.0;
                              for (var doc in filteredProducts) {
                                final data = doc.data();
                                final String productoId = doc.id;
                                // --- CORRECCIÓN 4: Leer stock como double ---
                                final double stockActual = (data['stock'] as num?)?.toDouble() ?? 0.0; 
                                final double capp = _costosPromedio[productoId] ?? 0.0;
                                
                                costoTotalInventario += (stockActual * capp);
                              }

                              return Column(
                                children: [
                                  // Costo Total de Inventario Global (usando el total de los productos filtrados)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Card(
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      color: Colors.blueGrey.shade100,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Costo Total de Inventario:',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey[800],
                                              ),
                                            ),
                                            Text(
                                              '\$${costoTotalInventario.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey[900],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  // Lista de Productos (Filtrados)
                                  Expanded(
                                    child: ListView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                      itemCount: filteredProducts.length,
                                      itemBuilder: (context, index) {
                                        final doc = filteredProducts[index];
                                        final data = doc.data();
                                        final String productoId = doc.id;
                                        final String nombre = data['nombre'] ?? 'Sin Nombre';
                                        // --- CORRECCIÓN 5: Leer stock y por_peso ---
                                        final double stockActual = (data['stock'] as num?)?.toDouble() ?? 0.0;
                                        final bool esPorPeso = data['por_peso'] ?? false;
                                        
                                        final double capp = _costosPromedio[productoId] ?? 0.0;
                                        final double costoTotalProducto = stockActual * capp;

                                        // Formato de stock y unidades
                                        final String stockText = stockActual.toStringAsFixed(esPorPeso ? 2 : 0);
                                        final String unidadText = esPorPeso ? 'Kg' : 'unidades';
                                        final String cappUnidadText = esPorPeso ? '/Kg' : '/unidad';


                                        return Card(
                                          margin: const EdgeInsets.symmetric(vertical: 6.0),
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nombre,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal[800],
                                                  ),
                                                ),
                                                const SizedBox(height: 5),
                                                // Mostrar stock con decimales si es por peso
                                                Text('Stock Actual: $stockText $unidadText'),
                                                Text('Costo Promedio Ponderado (CAPP): \$${capp.toStringAsFixed(2)}$cappUnidadText'),
                                                Text(
                                                  'Costo Total de Producto: \$${costoTotalProducto.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}