// lib/pages/productos_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_inventario/services/firestore_service.dart'; // Importar el servicio de Firestore

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final FirestoreService _firestoreService = FirestoreService();
  double? _tasaBCV;
  final int _stockBajoUmbral = 10;
  final TextEditingController _searchController = TextEditingController(); // Controlador para el campo de búsqueda
  String _searchText = ''; // Texto de búsqueda actual

  @override
  void initState() {
    super.initState();
    _cargarTasaBCV();
    // Escuchar cambios en el campo de búsqueda
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _cargarTasaBCV() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tasaBCV = prefs.getDouble('tasa_bcv') ?? 0.0;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Productos en Stock',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0), // Altura del campo de búsqueda
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto por nombre...',
                hintStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.blueAccent.shade700,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getCollectionStream('productos', orderByField: 'nombre'),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProductos = snapshot.data!.docs;
          
          // Filtrar productos basados en el texto de búsqueda
          final filteredProductos = allProductos.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombreProducto = (data['nombre'] ?? '').toLowerCase();
            return nombreProducto.contains(_searchText);
          }).toList();

          if (filteredProductos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    _searchText.isEmpty
                        ? 'No hay productos registrados.'
                        : 'No se encontraron productos para "${_searchText}"',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: filteredProductos.length,
            itemBuilder: (context, index) {
              final producto = filteredProductos[index].data() as Map<String, dynamic>;
              
              final String nombre = producto['nombre'] ?? 'Nombre no disponible';
              final double precioUSD = (producto['precio'] as num?)?.toDouble() ?? 0.0;
              final int stock = (producto['stock'] as num?)?.toInt() ?? 0;

              // Asegurarse de que _tasaBCV no sea nulo antes de usarlo
              final double precioBs = (_tasaBCV != null && _tasaBCV! > 0) ? precioUSD * _tasaBCV! : 0.0;
              final bool isStockBajo = stock <= _stockBajoUmbral;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.category,
                        size: 40,
                        color: isStockBajo ? Colors.redAccent : Colors.blueAccent,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombre,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Stock: $stock ${isStockBajo ? '(¡Bajo!)' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                color: isStockBajo ? Colors.red : Colors.green[700],
                                fontWeight: isStockBajo ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Precio: \$${precioUSD.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'Precio en Bs: Bs ${precioBs.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}