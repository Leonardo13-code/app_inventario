// lib/pages/entrada_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para FilteringTextInputFormatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_inventario/services/firestore_service.dart';

class EntradaPage extends StatefulWidget {
  const EntradaPage({super.key});

  @override
  State<EntradaPage> createState() => EntradaPageState();
}

class EntradaPageState extends State<EntradaPage> {
  final FirestoreService _firestoreService = FirestoreService();

  final _formKey = GlobalKey<FormState>();

  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController costoUnitarioController = TextEditingController();
  final TextEditingController proveedorController = TextEditingController();
  final TextEditingController documentoController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController motivoController = TextEditingController();

  String? _selectedProductId;
  String? _selectedProductName;
  bool _isProductPorPeso = false; // Nueva variable para mostrar si es por peso

  bool _isLoading = false;

  @override
  void dispose() {
    cantidadController.dispose();
    costoUnitarioController.dispose();
    proveedorController.dispose();
    documentoController.dispose();
    ubicacionController.dispose();
    motivoController.dispose();
    super.dispose();
  }

  // Función auxiliar para obtener los productos de Firestore
  Stream<QuerySnapshot> _getProductStream() {
    return _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots();
  }

  // --- LÓGICA DE REGISTRO DE ENTRADA CORREGIDA Y COMPLETA --
  Future<void> _registrarEntrada() async {
    if (_formKey.currentState!.validate() && _selectedProductId != null) {
      setState(() => _isLoading = true);

      // --- CAMBIO CLAVE: Leer cantidad y costo como double ---
      final double cantidad = double.tryParse(cantidadController.text) ?? 0.0;
      final double costoUnitario = double.tryParse(costoUnitarioController.text) ?? 0.0;

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showSnackbar('Error de autenticación. Intente iniciar sesión de nuevo.');
        setState(() => _isLoading = false);
        return;
      }

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final docRef = FirebaseFirestore.instance.collection('productos').doc(_selectedProductId);

      try {
        // 1. Obtener el stock actual
        final productSnapshot = await docRef.get();
        if (!productSnapshot.exists) {
          throw Exception('El producto seleccionado ya no existe.');
        }

        // Stock y la nueva cantidad deben ser tratados como double
        final double stockActual = (productSnapshot.data()?['stock'] as num?)?.toDouble() ?? 0.0;
        final double nuevoStock = stockActual + cantidad;

        // 2. Actualizar el stock del producto
        batch.update(docRef, {'stock': nuevoStock});

        // 3. Registrar el movimiento de entrada
        final movimientoData = {
          'productoId': _selectedProductId,
          'productoNombre': _selectedProductName,
          'tipo': 'Entrada',
          'fecha': Timestamp.now(),
          'cantidad': cantidad, // Cantidad es double
          'costoUnitario': costoUnitario, // Costo es double
          'proveedor': proveedorController.text.trim(),
          'documento': documentoController.text.trim(),
          'ubicacion': ubicacionController.text.trim(),
          'motivo': motivoController.text.trim(),
          'usuario': user.email, // Registrar el email del usuario
        };
        batch.set(FirebaseFirestore.instance.collection('movimientos').doc(), movimientoData);

        // 4. Ejecutar todas las operaciones atómicamente
        await batch.commit();

        _showSnackbar('Entrada de inventario registrada con éxito.', isError: false);
        _resetForm();

      } catch (e) {
        _showSnackbar('Error al registrar la entrada: ${e.toString()}');
        print('Error de registro de entrada: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }
  
  void _resetForm() {
    if (mounted) {
      setState(() {
        _selectedProductId = null;
        _selectedProductName = null;
        _isProductPorPeso = false;
        cantidadController.clear();
        costoUnitarioController.clear();
        proveedorController.clear();
        documentoController.clear();
        ubicacionController.clear();
        motivoController.clear();
        _formKey.currentState?.reset();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registro de Entrada',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Selector de Producto
              StreamBuilder<QuerySnapshot>(
                stream: _getProductStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Text('Error al cargar productos');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final items = snapshot.data!.docs;
                  
                  // Crear lista de DropdownMenuItem
                  final dropdownItems = items.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(data['nombre'] ?? 'Producto Desconocido'),
                    );
                  }).toList();

                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Producto',
                      prefixIcon: const Icon(Icons.inventory),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    value: _selectedProductId,
                    items: dropdownItems,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedProductId = newValue;
                        
                        // Obtener los datos del producto seleccionado para saber si es por peso
                        final selectedDoc = items.firstWhere((doc) => doc.id == newValue);
                        final data = selectedDoc.data() as Map<String, dynamic>;
                        _selectedProductName = data['nombre'] ?? 'Desconocido';
                        _isProductPorPeso = data['por_peso'] ?? false; // Actualizar el estado de "por peso"
                      });
                    },
                    validator: (v) => v == null ? 'Seleccione un producto' : null,
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // Campo Cantidad - AHORA ACEPTA DECIMALES
              TextFormField(
                controller: cantidadController,
                // --- CAMBIO CLAVE: Aceptar decimales y limitar a números ---
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Permite números y un punto decimal
                ],
                decoration: InputDecoration(
                  labelText: 'Cantidad de Entrada (${_isProductPorPeso ? 'Kg' : 'Unidades'})',
                  prefixIcon: const Icon(Icons.exposure_plus_1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  final cantidad = double.tryParse(v ?? '');
                  if (cantidad == null || cantidad <= 0) return 'Ingrese una cantidad válida (> 0)';
                  // Si NO es por peso, la cantidad debe ser entera
                  if (!_isProductPorPeso && cantidad != cantidad.truncateToDouble()) {
                    return 'La cantidad debe ser un número entero (unidades).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Campo Costo Unitario - AHORA ACEPTA DECIMALES
              TextFormField(
                controller: costoUnitarioController,
                // --- CAMBIO CLAVE: Aceptar decimales y limitar a números ---
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Permite números y un punto decimal
                ],
                decoration: InputDecoration(
                  labelText: 'Costo Unitario en USD (${_isProductPorPeso ? 'por Kg' : 'por unidad'})',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  final costo = double.tryParse(v ?? '');
                  if (costo == null || costo < 0) return 'Ingrese un costo unitario válido (>= 0)';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Campo Proveedor
              TextFormField(
                controller: proveedorController,
                decoration: InputDecoration(
                  labelText: 'Proveedor',
                  prefixIcon: const Icon(Icons.local_shipping),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'El proveedor es requerido' : null,
              ),
              const SizedBox(height: 20),
              
              // Campo Documento
              TextFormField(
                controller: documentoController,
                decoration: InputDecoration(
                  labelText: 'Número de Factura / Documento',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'El documento es requerido' : null,
              ),
              const SizedBox(height: 20),
              
              // Campo Ubicación
              TextFormField(
                controller: ubicacionController,
                decoration: InputDecoration(
                  labelText: 'Ubicación de Almacenamiento',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                // No es estrictamente requerido, así que no se usa validator por ahora.
              ),
              const SizedBox(height: 20),
              
              // Campo Motivo
              TextFormField(
                controller: motivoController,
                decoration: InputDecoration(
                  labelText: 'Motivo de la Entrada (Compra, Devolución, etc.)',
                  prefixIcon: const Icon(Icons.receipt),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'El motivo es requerido' : null,
              ),
              const SizedBox(height: 30),
              
              // Botón de Registrar Entrada con indicador de carga
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _registrarEntrada,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Registrando...' : 'Registrar Entrada',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
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