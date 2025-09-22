// lib/pages/salida_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_inventario/services/firestore_service.dart'; // Importar el servicio
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el usuario actual

class SalidaPage extends StatefulWidget {
  const SalidaPage({super.key});

  @override
  State<SalidaPage> createState() => SalidaPageState();
}

class SalidaPageState extends State<SalidaPage> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  // Controladores de los campos
  String? _selectedProductId; // ID del producto seleccionado
  String? _selectedProductName; // Nombre del producto seleccionado (para mostrar)
  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController clienteDepartamentoController = TextEditingController(); // Cliente o Departamento
  final TextEditingController documentoController = TextEditingController(); // Documento asociado
  final TextEditingController ubicacionController = TextEditingController(); // Ubicación de salida
  final TextEditingController motivoController = TextEditingController(); // Motivo de Salida

  int _currentProductStock = 0; // Stock del producto seleccionado actualmente

  @override
  void dispose() {
    cantidadController.dispose();
    clienteDepartamentoController.dispose();
    documentoController.dispose();
    ubicacionController.dispose();
    motivoController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _registrarSalida() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedProductId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, selecciona un producto.')),
          );
        }
        return;
      }

      try {
        final String productoId = _selectedProductId!;
        final String nombreProducto = _selectedProductName!; // Ya tenemos el nombre del producto
        final int cantidad = int.parse(cantidadController.text.trim());
        final String clienteDepartamento = clienteDepartamentoController.text.trim();
        final String documento = documentoController.text.trim();
        final String ubicacion = ubicacionController.text.trim();
        final String motivo = motivoController.text.trim();

        final User? currentUser = FirebaseAuth.instance.currentUser;
        final String usuario = currentUser?.email ?? 'Desconocido';

        // 1. Obtener el producto de Firestore para verificar el stock actual
        final productDoc = await _firestoreService.getDocument('productos', productoId);
        final productData = productDoc.data();
        
        if (productData == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Producto no encontrado o sin datos.')),
            );
          }
          return;
        }

        int currentStock = (productData['stock'] as num?)?.toInt() ?? 0;

        // 2. Validar que la cantidad de salida no exceda el stock actual
        if (cantidad <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La cantidad de salida debe ser un número positivo.')),
            );
          }
          return;
        }
        if (cantidad > currentStock) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Stock insuficiente. Disponible: $currentStock')),
            );
          }
          return;
        }

        // 3. Actualizar el stock del producto
        final newStock = currentStock - cantidad;
        await _firestoreService.updateDocument(
          'productos',
          productoId,
          {'stock': newStock},
        );

        // 4. Registrar el movimiento de salida
        await _firestoreService.addDocument('movimientos', {
          'productoId': productoId,
          'nombreProducto': nombreProducto, // Guardar el nombre del producto para evitar FutureBuilder en historial
          'cantidad': -cantidad, // La cantidad de salida es negativa
          'fecha': Timestamp.now(),
          'tipo': 'Salida', // Tipo de movimiento
          'clienteDepartamento': clienteDepartamento,
          'documento': documento,
          'ubicacion': ubicacion,
          'motivo': motivo,
          'usuario': usuario,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Salida registrada con éxito.")),
          );
          // Limpiar los campos después de un registro exitoso
          _formKey.currentState!.reset(); // Resetea el estado del formulario
          cantidadController.clear();
          clienteDepartamentoController.clear();
          documentoController.clear();
          ubicacionController.clear();
          motivoController.clear();
          setState(() {
            _selectedProductId = null; // Deseleccionar el producto
            _selectedProductName = null;
            _currentProductStock = 0;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al registrar salida: ${e.toString()}")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registrar Salida',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = snapshot.data?.docs ?? [];
                  if (products.isEmpty) {
                    return const Text('No hay productos disponibles.');
                  }

                  List<DropdownMenuItem<String>> productItems = products.map((doc) {
                    final data = doc.data();
                    final String nombre = data['nombre'] ?? 'Sin Nombre';
                    final int stock = (data['stock'] as num?)?.toInt() ?? 0;
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(
                        '$nombre (Stock: $stock)',
                        overflow: TextOverflow.ellipsis, // CORRECCIÓN: Manejar desbordamiento de texto
                        maxLines: 1, // CORRECCIÓN: Limitar a una línea
                      ),
                    );
                  }).toList();

                  // Asegurarse de que el valor seleccionado sea uno de los valores válidos
                  if (_selectedProductId != null && !products.any((doc) => doc.id == _selectedProductId)) {
                    _selectedProductId = null;
                    _selectedProductName = null;
                    _currentProductStock = 0;
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedProductId,
                    decoration: InputDecoration( // No const si necesitas fillColor
                      labelText: 'Seleccionar Producto',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Añadido borderRadius para consistencia
                      filled: true, // Añadido para fondo
                      fillColor: Colors.red.shade50, // Color de Salida
                    ),
                    isExpanded: true, // CORRECCIÓN: Expandir el Dropdown para ocupar el ancho disponible
                    items: productItems,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedProductId = newValue;
                        if (newValue != null) {
                          final selectedDoc = products.firstWhere((doc) => doc.id == newValue);
                          _selectedProductName = selectedDoc.data()['nombre'] ?? 'Sin Nombre';
                          _currentProductStock = (selectedDoc.data()['stock'] as num?)?.toInt() ?? 0;
                        } else {
                          _selectedProductName = null;
                          _currentProductStock = 0;
                        }
                      });
                    },
                    validator: (value) => value == null ? 'Por favor, selecciona un producto' : null,
                  );
                },
              ),
              const SizedBox(height: 20),
              if (_selectedProductId != null) // Muestra el stock solo si hay un producto seleccionado
                Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Text(
                    'Stock actual: $_currentProductStock unidades',
                    style: TextStyle(fontSize: 16, color: Colors.blueGrey[700]),
                  ),
                ),
              TextFormField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration( // No const
                  labelText: 'Cantidad de Salida',
                  prefixIcon: const Icon(Icons.remove_shopping_cart, color: Colors.red), // Icono
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Añadido borderRadius
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'La cantidad es requerida';
                  final parsedCantidad = int.tryParse(v);
                  if (parsedCantidad == null || parsedCantidad <= 0) {
                    return 'Ingrese una cantidad válida (número positivo)';
                  }
                  if (_selectedProductId != null && parsedCantidad > _currentProductStock) {
                    return 'La cantidad excede el stock disponible (Max: $_currentProductStock)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: clienteDepartamentoController,
                decoration: InputDecoration( // No const
                  labelText: 'Cliente/Departamento de Destino',
                  prefixIcon: const Icon(Icons.person), // Icono
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Añadido borderRadius
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: documentoController,
                decoration: InputDecoration( // No const
                  labelText: 'Documento Asociado (Factura, Guía, etc.)',
                  prefixIcon: const Icon(Icons.description), // Icono
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Añadido borderRadius
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: ubicacionController,
                decoration: InputDecoration( // No const
                  labelText: 'Ubicación de Salida (Ej: Almacén 2, Estante B)',
                  prefixIcon: const Icon(Icons.location_on), // Icono
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Añadido borderRadius
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: motivoController,
                decoration: InputDecoration( // No const
                  labelText: 'Motivo de Salida (Venta, Consumo, Daño, etc.)',
                  prefixIcon: const Icon(Icons.receipt), // Icono
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), // Añadido borderRadius
                ),
                validator: (v) => v!.isEmpty ? 'El motivo es requerido' : null,
              ),
              const SizedBox(height: 30),
              // CORRECCIÓN: Botón de Registrar Salida - Centrado y ancho completo
              SizedBox(
                width: double.infinity, // Hace que el botón ocupe todo el ancho
                child: ElevatedButton.icon(
                  onPressed: _registrarSalida,
                  icon: const Icon(Icons.remove_shopping_cart, color: Colors.white),
                  label: const Text(
                    'Registrar Salida',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}