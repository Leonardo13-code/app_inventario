import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EntradaPage extends StatefulWidget {
  const EntradaPage({super.key});

  @override
  _EntradaPageState createState() => _EntradaPageState();
}

class _EntradaPageState extends State<EntradaPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de los campos
  final TextEditingController productoIdController = TextEditingController();
  final TextEditingController nombreProductoController = TextEditingController();
  final TextEditingController cantidadController = TextEditingController();
  final TextEditingController proveedorController = TextEditingController();
  final TextEditingController documentoController = TextEditingController();
  final TextEditingController ubicacionController = TextEditingController();
  final TextEditingController motivoController = TextEditingController();
  final TextEditingController usuarioController = TextEditingController();

  Future<void> _registrarEntrada() async {
    if (_formKey.currentState!.validate()) {
      try {
        final productoId = productoIdController.text.trim();
        final nombre = nombreProductoController.text.trim();
        final cantidad = int.parse(cantidadController.text.trim());
        final proveedor = proveedorController.text.trim();
        final documento = documentoController.text.trim();
        final ubicacion = ubicacionController.text.trim();
        final motivo = motivoController.text.trim();
        final usuario = usuarioController.text.trim();
        final fecha = DateTime.now();
        final timestamp = FieldValue.serverTimestamp();

        // Guardar en Firestore colección 'entradas'
        await FirebaseFirestore.instance.collection('entradas').add({
          'productoId': productoId,
          'nombreProducto': nombre,
          'cantidad': cantidad,
          'proveedor': proveedor,
          'documento': documento,
          'ubicacion': ubicacion,
          'motivo': motivo,
          'usuario': usuario,
          'fecha': DateFormat('yyyy-MM-dd HH:mm:ss').format(fecha),
          'timestamp': timestamp,
        });

        // Actualizar stock del producto
        final productoRef = FirebaseFirestore.instance.collection('productos').doc(productoId);
        final productoSnapshot = await productoRef.get();
        if (productoSnapshot.exists) {
          final data = productoSnapshot.data();
          final stockActual = (data?['stock'] ?? 0) as int;
          await productoRef.update({'stock': stockActual + cantidad});
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrada registrada correctamente')),
        );

        // Limpiar campos
        _formKey.currentState!.reset();
        productoIdController.clear();
        nombreProductoController.clear();
        cantidadController.clear();
        proveedorController.clear();
        documentoController.clear();
        ubicacionController.clear();
        motivoController.clear();
        usuarioController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar entrada: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    productoIdController.dispose();
    nombreProductoController.dispose();
    cantidadController.dispose();
    proveedorController.dispose();
    documentoController.dispose();
    ubicacionController.dispose();
    motivoController.dispose();
    usuarioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Entrada')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: productoIdController, decoration: const InputDecoration(labelText: 'ID del Producto'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
              TextFormField(controller: nombreProductoController, decoration: const InputDecoration(labelText: 'Nombre del Producto'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
              TextFormField(controller: cantidadController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cantidad'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
              TextFormField(controller: proveedorController, decoration: const InputDecoration(labelText: 'Proveedor')),
              TextFormField(controller: documentoController, decoration: const InputDecoration(labelText: 'Documento Asociado')),
              TextFormField(controller: ubicacionController, decoration: const InputDecoration(labelText: 'Ubicación')),
              TextFormField(controller: motivoController, decoration: const InputDecoration(labelText: 'Motivo de Entrada')),
              TextFormField(controller: usuarioController, decoration: const InputDecoration(labelText: 'Usuario Responsable')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _registrarEntrada, child: const Text('Guardar Entrada')),
            ],
          ),
        ),
      ),
    );
  }
}
