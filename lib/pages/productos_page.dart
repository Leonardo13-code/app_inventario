// lib/pages/productos_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:InVen/services/firestore_service.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  final FirestoreService _firestoreService = FirestoreService();
  double? _tasaConversion; // Renombrado a _tasaConversion para mayor claridad
  final int _stockBajoUmbral = 10;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _cargarTasaConversion();
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text.toLowerCase();
      });
    });
  }

  // --- NUEVO: Método para cargar la tasa de conversión ---
  Future<void> _cargarTasaConversion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Usar la clave genérica 'tasa_conversion' para la conversión en la app
      _tasaConversion = prefs.getDouble('tasa_conversion') ?? 0.0;
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
        title: const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: const TextStyle(color: Colors.white),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.blue.shade700,
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay productos registrados."));
          }

          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = data['nombre'].toString().toLowerCase();
            return nombre.contains(_searchText);
          }).toList();

          return ListView.builder(
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final product = filteredDocs[index].data() as Map<String, dynamic>;
              final String nombre = product['nombre'] ?? 'Sin nombre';
              final double precioUSD = (product['precio'] ?? 0.0).toDouble();
              final int stock = (product['stock'] ?? 0).toInt();
              final bool isStockBajo = stock <= _stockBajoUmbral;

              // Calcula el precio en Bs, asegurando que _tasaConversion no sea nula
              final double precioBs = precioUSD * (_tasaConversion ?? 0.0);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag, size: 40, color: Colors.blueAccent),
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
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Stock: $stock ${isStockBajo ? '(¡Bajo!)' : ''}',
                              style: TextStyle(
                                fontSize: 16,
                                color: isStockBajo ? Colors.red : Colors.green.shade700,
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