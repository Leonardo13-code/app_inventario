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

  Map<String, double> _costosPromedio = {};
  bool _isLoading = true; // Para controlar el estado de carga
  String? _errorMessage; // Para almacenar mensajes de error

  @override
  void initState() {
    super.initState();
    _calcularCostosPromedio();
  }

  Future<void> _calcularCostosPromedio() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Limpiar cualquier mensaje de error anterior
    });

    try {
      final Map<String, List<Map<String, dynamic>>> productMovements = {};

      // 1. Obtener todos los movimientos de entrada
      final querySnapshot = await _firestoreService.getCollectionOnce('movimientos');
      
      for (var doc in querySnapshot.docs) {
        final data = doc.data(); // Esto es Map<String, dynamic>, no será null

        // --- CORRECCIÓN: Manejo de valores nulos para productoId y tipo ---
        final String? productoIdNullable = data['productoId'];
        final String? tipoNullable = data['tipo'];

        // Si productoId es null, el movimiento es inválido para el cálculo de costos.
        if (productoIdNullable == null) {
          print('Advertencia: Documento de movimiento ${doc.id} tiene productoId nulo. Saltando.');
          continue; // Salta este documento si el productoId es nulo.
        }
        final String productoId = productoIdNullable; // Ahora sabemos que no es nulo.
        
        // Si tipo es null, usa una cadena vacía como valor por defecto.
        final String tipo = tipoNullable ?? ''; 
        // --- FIN CORRECCIÓN ---

        final int cantidad = (data['cantidad'] is num ? (data['cantidad'] as num).abs().toInt() : 0); 
        final double costoUnitario = (data['costoUnitario'] as num?)?.toDouble() ?? 0.0; 

        if (!productMovements.containsKey(productoId)) {
          productMovements[productoId] = [];
        }
        productMovements[productoId]!.add({
          'tipo': tipo,
          'cantidad': cantidad,
          'costoUnitario': costoUnitario,
        });
      }

      final Map<String, double> calculatedCosts = {};

      // 2. Calcular el costo promedio ponderado para cada producto
      for (var productId in productMovements.keys) {
        final List<Map<String, dynamic>> movements = productMovements[productId]!;
        
        double totalCost = 0.0;
        int totalQuantity = 0;

        for (var movement in movements) {
          // Asegurarse de que 'tipo' y 'cantidad' existan y sean del tipo esperado
          if (movement['tipo'] == 'Entrada') {
            // Asegurarse de que 'cantidad' sea un int para la suma y multiplicación
            final int movementCantidad = (movement['cantidad'] is num ? (movement['cantidad'] as num).toInt() : 0);
            final double movementCostoUnitario = (movement['costoUnitario'] is num ? (movement['costoUnitario'] as num).toDouble() : 0.0);

            totalCost += (movementCantidad * movementCostoUnitario);
            totalQuantity += movementCantidad; 
          }
        }
        
        if (totalQuantity > 0) {
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
          print('Error en _calcularCostosPromedio: $e'); // Para depuración
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
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error al cargar productos: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final productos = snapshot.data?.docs ?? [];

                        if (productos.isEmpty) {
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

                        // Calcular el costo total del inventario
                        double costoTotalInventario = 0.0;
                        for (var doc in productos) {
                          final data = doc.data();
                          final String productoId = doc.id;
                          final int stockActual = (data['stock'] as num?)?.toInt() ?? 0;
                          final double capp = _costosPromedio[productoId] ?? 0.0;
                          costoTotalInventario += (stockActual * capp);
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey[800],
                                        ),
                                      ),
                                      Text(
                                        '\$${costoTotalInventario.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                itemCount: productos.length,
                                itemBuilder: (context, index) {
                                  final doc = productos[index];
                                  final data = doc.data();
                                  final String productoId = doc.id;
                                  final String nombre = data['nombre'] ?? 'Sin Nombre';
                                  final int stockActual = (data['stock'] as num?)?.toInt() ?? 0;
                                  final double capp = _costosPromedio[productoId] ?? 0.0;
                                  final double costoTotalProducto = stockActual * capp;

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
                                          Text('Stock Actual: $stockActual unidades'),
                                          Text('Costo Promedio Ponderado (CAPP): \$${capp.toStringAsFixed(2)}/unidad'),
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
    );
  }
}