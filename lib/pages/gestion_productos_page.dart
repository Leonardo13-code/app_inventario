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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
              final data = productoDoc.data();
              final String nombre = data['nombre'] ?? 'Sin Nombre';
              final double precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
              final double stock = (data['stock'] as num?)?.toDouble() ?? 0.0;
              final bool esPorPeso = data['por_peso'] ?? false;
              final bool esExentoIva = data['exento_iva'] ?? false; // NUEVO CAMPO

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 5.0),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Icon(esPorPeso ? Icons.scale : Icons.inventory_2, color: Colors.purple),
                  title: Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Precio: \$${precio.toStringAsFixed(2)} ${esPorPeso ? '/Kg' : '/u'}'),
                      Text('Stock: ${stock.toStringAsFixed(esPorPeso ? 2 : 0)} ${esPorPeso ? 'Kg' : 'unidades'}'),
                      Text(
                        esExentoIva ? 'EXENTO DE IVA' : 'APLICA IVA (16%)', // Mostrar estado IVA
                        style: TextStyle(
                          fontStyle: FontStyle.italic, 
                          color: esExentoIva ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
      // Añadida exentoIva a la firma de onSave
      onSave: (nombre, precio, stock, esPorPeso, exentoIva) async { 
        try {
          final existingProducts = await _firestoreService.getCollectionOnce(
            'productos',
          );
          bool productExists = existingProducts.docs.any((doc) {
            final data = doc.data();
            return (data['nombre'] as String?)?.toLowerCase() == nombre.toLowerCase();
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
            'stock': stock.toDouble(),
            'por_peso': esPorPeso,
            'exento_iva': exentoIva, // NUEVO CAMPO A GUARDAR
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
  void _editarProducto(DocumentSnapshot<Map<String, dynamic>> productoDoc) {
    final data = productoDoc.data();
    final String id = productoDoc.id;
    final String currentNombre = data?['nombre'] ?? '';
    final double currentPrecio = (data?['precio'] as num?)?.toDouble() ?? 0.0;
    final double currentStock = (data?['stock'] as num?)?.toDouble() ?? 0.0;
    final bool currentEsPorPeso = data?['por_peso'] ?? false;
    final bool currentExentoIva = data?['exento_iva'] ?? false; // NUEVO CAMPO

    _mostrarDialogoProducto(
      context,
      title: 'Editar Producto',
      nombreInicial: currentNombre,
      precioInicial: currentPrecio,
      stockInicial: currentStock,
      esPorPesoInicial: currentEsPorPeso,
      exentoIvaInicial: currentExentoIva, // PASAR VALOR INICIAL
      // Añadida exentoIva a la firma de onSave
      onSave: (nombre, precio, stock, esPorPeso, exentoIva) async { 
        try {
          final existingProducts = await _firestoreService.getCollectionOnce(
            'productos',
          );
          bool productExists = existingProducts.docs.any((doc) {
            if (doc.id == id) return false;
            final existingData = doc.data();
            return (existingData['nombre'] as String?)?.toLowerCase() == nombre.toLowerCase();
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
            'stock': stock.toDouble(),
            'por_peso': esPorPeso,
            'exento_iva': exentoIva, // NUEVO CAMPO A ACTUALIZAR
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

  // Método para confirmar la eliminación de un producto (sin cambios)
  void _confirmarEliminarProducto(String productId, String productName) {
    // ... (Tu función _confirmarEliminarProducto permanece igual)
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

// Diálogo reutilizable para agregar/editar producto - ACTUALIZADO
class _ProductoFormDialog extends StatefulWidget {
  final String title;
  final String? nombreInicial;
  final double? precioInicial;
  final double? stockInicial;
  final bool? esPorPesoInicial;
  final bool? exentoIvaInicial; // NUEVO CAMPO
  // Añadida la variable 'exentoIva' a la firma de onSave
  final Future<bool> Function(String nombre, double precio, double stock, bool esPorPeso, bool exentoIva) onSave; 

  const _ProductoFormDialog({
    required this.title,
    this.nombreInicial,
    this.precioInicial,
    this.stockInicial,
    this.esPorPesoInicial,
    this.exentoIvaInicial, // Recibir valor inicial
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
  late bool _esPorPeso;
  late bool _esExentoIva; // NUEVA VARIABLE DE ESTADO

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.nombreInicial);
    _precioController = TextEditingController(text: widget.precioInicial?.toString());
    _stockController = TextEditingController(text: widget.stockInicial?.toStringAsFixed(2)); 
    _esPorPeso = widget.esPorPesoInicial ?? false;
    _esExentoIva = widget.exentoIvaInicial ?? false; // Inicializar
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
                decoration: InputDecoration(labelText: 'Precio en USD ${ _esPorPeso ? ' (por Kg)' : ' (por unidad)'}'),
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
                decoration: InputDecoration(labelText: 'Stock Inicial (${ _esPorPeso ? 'Kg' : 'unidades'})'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El stock inicial es requerido';
                  final parsedValue = double.tryParse(v);
                  if (parsedValue == null || parsedValue < 0) return 'Ingrese un stock válido (número positivo o cero)';
                  
                  if (!_esPorPeso && parsedValue != parsedValue.truncate()) {
                      return 'El stock por unidad debe ser un número entero.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 15),
              // SWITCH PARA 'POR PESO'
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Se vende por peso (Kg)'),
                  Switch(
                    value: _esPorPeso,
                    onChanged: (bool newValue) {
                      setState(() {
                        _esPorPeso = newValue;
                        _formKey.currentState?.validate();
                      });
                    },
                  ),
                ],
              ),
              // NUEVO SWITCH PARA 'EXENTO DE IVA'
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Exento de IVA'),
                  Switch(
                    value: _esExentoIva,
                    onChanged: (bool newValue) {
                      setState(() {
                        _esExentoIva = newValue;
                      });
                    },
                  ),
                ],
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
                double.tryParse(_stockController.text.trim()) ?? 0.0,
                _esPorPeso,
                _esExentoIva, // Enviamos el valor del switch de IVA
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

// Función auxiliar para mostrar el diálogo de producto - ACTUALIZADA
void _mostrarDialogoProducto(
  BuildContext context, {
  required String title,
  String? nombreInicial,
  double? precioInicial,
  double? stockInicial,
  bool? esPorPesoInicial,
  bool? exentoIvaInicial, // NUEVO CAMPO
  // NUEVA FIRMA
  required Future<bool> Function(String nombre, double precio, double stock, bool esPorPeso, bool exentoIva) onSave, 
}) {
  showDialog(
    context: context,
    builder: (dialogContext) => _ProductoFormDialog(
      title: title,
      nombreInicial: nombreInicial,
      precioInicial: precioInicial,
      stockInicial: stockInicial,
      esPorPesoInicial: esPorPesoInicial,
      exentoIvaInicial: exentoIvaInicial, // Pasar valor
      onSave: onSave,
    ),
  );
}