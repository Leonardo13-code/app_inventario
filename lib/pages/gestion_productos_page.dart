// lib/pages/gestion_productos_page.dart
import 'package:flutter/material.dart';
import 'package:app_inventario/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Necesario para DocumentSnapshot

class GestionProductosPage extends StatefulWidget {
  const GestionProductosPage({super.key});

  @override
  State<GestionProductosPage> createState() => _GestionProductosPageState();
}

class _GestionProductosPageState extends State<GestionProductosPage> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestionar Productos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>( // Aseguramos el tipo del StreamBuilder
        stream: _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No hay productos registrados. Agrega uno!'));
          }

          final productos = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final productoDoc = productos[index];
              // FINALMENTE, eliminamos el casteo explícito, ya que el conversor lo maneja
              final data = productoDoc.data(); // <--- CORRECCIÓN AQUÍ (Línea 109)
              final String nombre = data['nombre'] ?? 'Sin Nombre';
              final double precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
              final int stock = (data['stock'] as num?)?.toInt() ?? 0;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  title: Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Precio: \$${precio.toStringAsFixed(2)}'),
                      Text('Stock: $stock unidades'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editarProducto(productoDoc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmarEliminarProducto(productoDoc.id, nombre),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarProducto,
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        tooltip: 'Agregar Nuevo Producto',
        child: const Icon(Icons.add),
      ),
    );
  }

  // Método para agregar un nuevo producto
  void _agregarProducto() {
    _mostrarDialogoProducto(
      context,
      title: 'Agregar Nuevo Producto',
      onSave: (nombre, precio, stock) async {
        try {
          // Verificar si ya existe un producto con el mismo nombre
          final existingProducts = await _firestoreService.getCollectionOnce(
            'productos',
          );
          bool productExists = existingProducts.docs.any((doc) {
            final data = doc.data(); // Eliminado el casteo
            return (data?['nombre'] as String?)?.toLowerCase() == nombre.toLowerCase();
          });

          if (productExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ya existe un producto con este nombre.')),
              );
            }
            return false;
          }

          await _firestoreService.addDocument('productos', {
            'nombre': nombre,
            'precio': precio,
            'stock': stock,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Producto agregado con éxito.")),
            );
          }
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al agregar producto: ${e.toString()}")),
            );
          }
          return false;
        }
      },
    );
  }

  // Método para editar un producto existente
  void _editarProducto(DocumentSnapshot<Map<String, dynamic>> productoDoc) { // Aseguramos el tipo
    final data = productoDoc.data(); // Eliminado el casteo
    final String id = productoDoc.id;
    final String currentNombre = data?['nombre'] ?? '';
    final double currentPrecio = (data?['precio'] as num?)?.toDouble() ?? 0.0;
    final int currentStock = (data?['stock'] as num?)?.toInt() ?? 0;

    _mostrarDialogoProducto(
      context,
      title: 'Editar Producto',
      nombreInicial: currentNombre,
      precioInicial: currentPrecio,
      stockInicial: currentStock,
      onSave: (nombre, precio, stock) async {
        try {
          // Verificar si ya existe un producto con el mismo nombre, excluyendo el actual
          final existingProducts = await _firestoreService.getCollectionOnce(
            'productos',
          );
          bool productExists = existingProducts.docs.any((doc) {
            if (doc.id == id) return false;
            final existingData = doc.data(); // <--- CORRECCIÓN AQUÍ (Línea 167)
            return (existingData?['nombre'] as String?)?.toLowerCase() == nombre.toLowerCase();
          });

          if (productExists) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ya existe otro producto con este nombre.')),
              );
            }
            return false;
          }

          await _firestoreService.updateDocument('productos', id, {
            'nombre': nombre,
            'precio': precio,
            'stock': stock,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Producto actualizado con éxito.")),
            );
          }
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error al actualizar producto: ${e.toString()}")),
            );
          }
          return false;
        }
      },
    );
  }

  // Método para confirmar la eliminación de un producto
  void _confirmarEliminarProducto(String productId, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar el producto "$productName"? Esto es irreversible y no afectará el historial de movimientos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.deleteDocument('productos', productId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Producto "$productName" eliminado con éxito.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar producto: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Diálogo reutilizable para agregar/editar producto
class _ProductoFormDialog extends StatefulWidget {
  final String title;
  final String? nombreInicial;
  final double? precioInicial;
  final int? stockInicial;
  final Future<bool> Function(String nombre, double precio, int stock) onSave;

  const _ProductoFormDialog({
    required this.title,
    this.nombreInicial,
    this.precioInicial,
    this.stockInicial,
    required this.onSave,
  });

  @override
  State<_ProductoFormDialog> createState() => _ProductoFormDialogState();
}

class _ProductoFormDialogState extends State<_ProductoFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreController;
  late TextEditingController _precioController;
  late TextEditingController _stockController;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.nombreInicial);
    _precioController = TextEditingController(text: widget.precioInicial?.toString());
    _stockController = TextEditingController(text: widget.stockInicial?.toString());
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                  return null;
                },
              ),
              TextFormField(
                controller: _precioController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio en USD'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El precio es requerido';
                  final parsedValue = double.tryParse(v);
                  if (parsedValue == null || parsedValue < 0) return 'Ingrese un precio válido (número positivo)';
                  return null;
                },
              ),
              TextFormField(
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Stock Inicial'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El stock inicial es requerido';
                  final parsedValue = int.tryParse(v);
                  if (parsedValue == null || parsedValue < 0) return 'Ingrese un stock válido (número entero positivo o cero)';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final bool saved = await widget.onSave(
                _nombreController.text.trim(),
                double.tryParse(_precioController.text.trim()) ?? 0.0,
                int.tryParse(_stockController.text.trim()) ?? 0,
              );
              if (mounted && saved) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// Función auxiliar para mostrar el diálogo de producto
void _mostrarDialogoProducto(
  BuildContext context, {
  required String title,
  String? nombreInicial,
  double? precioInicial,
  int? stockInicial,
  required Future<bool> Function(String nombre, double precio, int stock) onSave,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => _ProductoFormDialog(
      title: title,
      nombreInicial: nombreInicial,
      precioInicial: precioInicial,
      stockInicial: stockInicial,
      onSave: onSave,
    ),
  );
}