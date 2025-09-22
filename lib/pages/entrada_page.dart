// lib/pages/entrada_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Para obtener el usuario actual
import 'package:app_inventario/services/firestore_service.dart'; // Importar el servicio

class EntradaPage extends StatefulWidget {
  const EntradaPage({super.key});

  @override
  State<EntradaPage> createState() => EntradaPageState(); // Cambiado de _EntradaPageState para consistencia
}

class EntradaPageState extends State<EntradaPage> {
  final FirestoreService _firestoreService = FirestoreService();

  final _formKey = GlobalKey<FormState>();

  // Controladores de los campos
  final TextEditingController cantidadController = TextEditingController();
  // NUEVO: Controlador para el costo unitario
  final TextEditingController costoUnitarioController = TextEditingController();
  final TextEditingController proveedorController = TextEditingController();
  final TextEditingController documentoController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController motivoController = TextEditingController();
  // El usuario ya no será un campo de entrada manual, se obtendrá de Firebase Auth
  // final TextEditingController usuarioController = TextEditingController();

  // Para seleccionar un producto de una lista
  String? _selectedProductId;
  String? _selectedProductName;
  List<DocumentSnapshot> _productosDisponibles = [];

  @override
  void initState() {
    super.initState();
    _cargarProductosDisponibles();
    // Establecer el valor inicial del motivo
    motivoController.text = 'Compra';
    // No pre-llenamos el usuarioController porque ahora se obtiene de FirebaseAuth.
    // Si quieres un valor por defecto para el campo de usuario (si se mostrara),
    // lo harías aquí, pero lo mejor es obtenerlo de FirebaseAuth.
  }

  // Carga la lista de productos existentes para el Dropdown
  Future<void> _cargarProductosDisponibles() async {
    try {
      final snapshot = await _firestoreService.getCollectionOnce('productos', orderByField: 'nombre');
      if (mounted) {
        setState(() {
          _productosDisponibles = snapshot.docs;
        });
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _registrarEntrada() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedProductId == null || _selectedProductName == null) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Por favor, selecciona un producto.')),
          );
        }
        return;
      }

      try {
        final String productoId = _selectedProductId!;
        final String nombreProducto = _selectedProductName!;
        final int cantidad = int.parse(cantidadController.text.trim());
        // NUEVO: Obtener el costo unitario
        final double costoUnitario = double.parse(costoUnitarioController.text.trim());
        final String proveedor = proveedorController.text.trim();
        final String documento = documentoController.text.trim();
        final String ubicacion = ubicacionController.text.trim();
        final String motivo = motivoController.text.trim();

        // Obtener el usuario autenticado (como en SalidaPage)
        final User? currentUser = FirebaseAuth.instance.currentUser;
        final String usuario = currentUser?.email ?? 'Desconocido'; // Usa el email o 'Desconocido'

        // 1. Registrar el movimiento
        await _firestoreService.addDocument('movimientos', {
          'productoId': productoId,
          'nombreProducto': nombreProducto,
          'cantidad': cantidad, // Cantidad positiva para entrada
          'costoUnitario': costoUnitario, // AÑADIDO: Campo de costo unitario
          'fecha': Timestamp.now(),
          'tipo': 'Entrada', // Coherente con SalidaPage
          'proveedor': proveedor.isNotEmpty ? proveedor : 'N/A',
          'documento': documento.isNotEmpty ? documento : 'N/A',
          'ubicacion': ubicacion.isNotEmpty ? ubicacion : 'N/A',
          'motivo': motivo.isNotEmpty ? motivo : 'Compra',
          'usuario': usuario, // Usar el usuario de FirebaseAuth
        });

        // 2. Actualizar el stock del producto
        final docSnapshot = await _firestoreService.getDocument('productos', productoId);
        if (docSnapshot.exists) {
          final currentStock = (docSnapshot.data()?['stock'] as num?)?.toInt() ?? 0;
          final newStock = currentStock + cantidad;

          await _firestoreService.updateDocument('productos', productoId, {
            'stock': newStock,
            // Podrías actualizar el precio de venta si fuera necesario aquí,
            // pero el CAPP ya lo maneja en los movimientos.
          });
        } else {
          // Si por alguna razón el producto no existe (ej. fue borrado)
          // se podría crear, o mostrar un error. Para este flujo, se asume que existe.
          if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Producto no encontrado para actualizar stock.')),
            );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Entrada registrada y stock actualizado con éxito.")),
          );
          _limpiarCampos(); // Limpiar el formulario después del éxito
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al registrar entrada: ${e.toString()}")),
          );
        }
      }
    }
  }

  void _limpiarCampos() {
    setState(() {
      _selectedProductId = null;
      _selectedProductName = null;
    });
    cantidadController.clear();
    costoUnitarioController.clear(); // Limpiar también el nuevo controlador
    proveedorController.clear();
    documentoController.clear();
    ubicacionController.clear();
    motivoController.clear();
    // usuarioController.clear(); // Ya no es necesario
  }

  @override
  void dispose() {
    cantidadController.dispose();
    costoUnitarioController.dispose(); // Limpiar el nuevo controlador
    proveedorController.dispose();
    documentoController.dispose();
    ubicacionController.dispose();
    motivoController.dispose();
    // usuarioController.dispose(); // Ya no es necesario
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registrar Entrada',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // <--- AÑADIDO: Estirar los hijos horizontalmente
            children: [
              const Text(
                'Selecciona un producto:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // ... (DropdownButtonFormField)
              DropdownButtonFormField<String>(
                value: _selectedProductId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.green.shade50,
                  hintText: 'Selecciona un producto',
                ),
                hint: const Text('Selecciona un producto'),
                isExpanded: true,
                items: _productosDisponibles.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(data['nombre'] ?? 'Producto sin nombre'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedProductId = newValue;
                    _selectedProductName = (_productosDisponibles
                        .firstWhere((doc) => doc.id == newValue)
                        .data() as Map<String, dynamic>?)?['nombre'] as String?;
                  });
                },
                validator: (value) => value == null ? 'Por favor selecciona un producto' : null,
              ),
              const SizedBox(height: 20),
              // ... (TextFormField para Cantidad)
              TextFormField(
                controller: cantidadController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Cantidad de Entrada',
                  prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final parsedValue = int.tryParse(v);
                  if (parsedValue == null || parsedValue <= 0) return 'Cantidad debe ser un número positivo';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // ... (TextFormField para Costo Unitario)
              TextFormField(
                controller: costoUnitarioController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Costo Unitario de Compra (USD)',
                  prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'El costo unitario es requerido';
                  final parsedCosto = double.tryParse(v);
                  if (parsedCosto == null || parsedCosto < 0) {
                    return 'Ingrese un costo unitario válido (positivo)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // ... (resto de tus TextFormField)
              TextFormField(
                controller: proveedorController,
                decoration: InputDecoration(
                  labelText: 'Proveedor',
                  prefixIcon: const Icon(Icons.local_shipping),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: documentoController,
                decoration: InputDecoration(
                  labelText: 'Documento Asociado (Factura, Guía, etc.)',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: ubicacionController,
                decoration: InputDecoration(
                  labelText: 'Ubicación (Almacén, Estante, etc.)',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: motivoController,
                decoration: InputDecoration(
                  labelText: 'Motivo de Entrada',
                  prefixIcon: const Icon(Icons.receipt),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'El motivo es requerido' : null,
              ),
              const SizedBox(height: 30),
              // --- CORRECCIÓN: Botón de Registrar Entrada ---
              // Envuelve el botón en un SizedBox para darle un ancho infinito
              SizedBox(
                width: double.infinity, // <--- Hace que el botón ocupe todo el ancho
                child: ElevatedButton.icon(
                  onPressed: _registrarEntrada,
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                  label: const Text(
                    'Registrar Entrada',
                    style: TextStyle(fontSize: 18, color: Colors.white),
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