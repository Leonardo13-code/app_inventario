// lib/pages/salida_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para FilteringTextInputFormatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:InVen/services/firestore_service.dart';

class SalidaPage extends StatefulWidget {
  const SalidaPage({super.key});

  @override
  State<SalidaPage> createState() => SalidaPageState();
}

class SalidaPageState extends State<SalidaPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  String? _selectedProductId;
  String? _selectedProductName;
  double _currentProductStock = 0.0; // CAMBIO CLAVE: Stock ahora es double
  bool _isProductPorPeso = false; // Nueva variable para mostrar si es por peso

  bool _isLoading = false;

  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController motivoController = TextEditingController();

  @override
  void dispose() {
    cantidadController.dispose();
    ubicacionController.dispose();
    motivoController.dispose();
    super.dispose();
  }

  // Función auxiliar para obtener los productos de Firestore
  Stream<QuerySnapshot> _getProductStream() {
    return _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots();
  }

  Future<void> _registrarSalida() async {
    if (_formKey.currentState!.validate() && _selectedProductId != null) {
      setState(() => _isLoading = true);
      
      // --- CAMBIO CLAVE: Leer cantidad como double ---
      final double cantidad = double.tryParse(cantidadController.text) ?? 0.0;
      
      if (cantidad <= 0) {
        _showSnackbar('La cantidad debe ser mayor a cero.');
        setState(() => _isLoading = false);
        return;
      }
      
      // --- CAMBIO CLAVE: Comparar con stock double ---
      if (cantidad > _currentProductStock) {
        _showSnackbar('No hay suficiente stock disponible (Stock: ${_currentProductStock.toStringAsFixed(_isProductPorPeso ? 2 : 0)} ${_isProductPorPeso ? 'Kg' : 'unidades'}).');
        setState(() => _isLoading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackbar('Error de autenticación. Intente iniciar sesión de nuevo.');
        setState(() => _isLoading = false);
        return;
      }

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final docRef = FirebaseFirestore.instance.collection('productos').doc(_selectedProductId);

      try {
        // 1. Obtener el costo unitario para registrar el movimiento (CAPP idealmente, pero usaremos el precio de venta como proxy)
        // **NOTA: En una implementación avanzada, se obtendría el CAPP. Por ahora, se utiliza 0.0, ya que el costo se calcula aparte en CostosPage.**
        final double costoUnitario = 0.0; 

        // 2. Actualizar el stock del producto
        final double nuevoStock = _currentProductStock - cantidad;
        batch.update(docRef, {'stock': nuevoStock});

        // 3. Registrar el movimiento de salida
        final movimientoData = {
          'productoId': _selectedProductId,
          'productoNombre': _selectedProductName,
          'tipo': 'Salida',
          'fecha': Timestamp.now(),
          'cantidad': -cantidad, // Cantidad es negativa para salidas
          'costoUnitario': costoUnitario,
          'proveedor': '', // No aplica
          'documento': '', // No aplica, a menos que se use un documento interno
          'ubicacion': ubicacionController.text.trim(),
          'motivo': motivoController.text.trim(),
          'usuario': user.email,
        };
        batch.set(FirebaseFirestore.instance.collection('movimientos').doc(), movimientoData);

        // 4. Ejecutar todas las operaciones atómicamente
        await batch.commit();

        _showSnackbar('Salida de inventario registrada con éxito.', isError: false);
        _resetForm();

      } catch (e) {
        _showSnackbar('Error al registrar la salida: ${e.toString()}');
        print('Error de registro de salida: $e');
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
        _currentProductStock = 0.0;
        _isProductPorPeso = false;
        cantidadController.clear();
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
          'Registro de Salida',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.red,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
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
                        
                        // Obtener los datos del producto seleccionado para stock y peso
                        final selectedDoc = items.firstWhere((doc) => doc.id == newValue);
                        final data = selectedDoc.data() as Map<String, dynamic>;
                        _selectedProductName = data['nombre'] ?? 'Desconocido';
                        // --- CAMBIO CLAVE: Leer stock como double ---
                        _currentProductStock = (data['stock'] as num?)?.toDouble() ?? 0.0;
                        _isProductPorPeso = data['por_peso'] ?? false;
                      });
                    },
                    validator: (v) => v == null ? 'Seleccione un producto' : null,
                  );
                },
              ),
              const SizedBox(height: 10),
              
              // Mostrar Stock Actual (Actualizado para double y peso)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Stock Actual: ${_currentProductStock.toStringAsFixed(_isProductPorPeso ? 2 : 0)} ${_isProductPorPeso ? 'Kg' : 'unidades'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
              ),

              const SizedBox(height: 10),
              
              // Campo Cantidad - AHORA ACEPTA DECIMALES
              TextFormField(
                controller: cantidadController,
                // --- CAMBIO CLAVE: Aceptar decimales y limitar a números ---
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')), // Permite números y un punto decimal
                ],
                decoration: InputDecoration(
                  labelText: 'Cantidad de Salida (${_isProductPorPeso ? 'Kg' : 'Unidades'})',
                  prefixIcon: const Icon(Icons.exposure_minus_1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  final cantidad = double.tryParse(v ?? '');
                  if (cantidad == null || cantidad <= 0) return 'Ingrese una cantidad válida (> 0)';
                  
                  // Si NO es por peso, la cantidad debe ser entera
                  if (!_isProductPorPeso && cantidad != cantidad.truncateToDouble()) {
                    return 'La cantidad debe ser un número entero (unidades).';
                  }
                  
                  // Comparación con stock
                  if (cantidad > _currentProductStock) {
                    return 'Excede el stock disponible.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Campo Ubicación
              TextFormField(
                controller: ubicacionController,
                decoration: InputDecoration(
                  labelText: 'Ubicación de Origen',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                // No es estrictamente requerido.
              ),
              const SizedBox(height: 20),
              
              // Campo Motivo
              TextFormField(
                controller: motivoController,
                decoration: InputDecoration(
                  labelText: 'Motivo de Salida (Daño, Desperdicio, etc.)',
                  prefixIcon: const Icon(Icons.receipt),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'El motivo es requerido' : null,
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _registrarSalida,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.remove_shopping_cart, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Registrando...' : 'Registrar Salida',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
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