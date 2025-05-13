import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductosPage extends StatelessWidget {
  const ProductosPage({super.key});

  void _agregarProducto(BuildContext context) async {
    final nuevoProducto = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _DialogoAgregarProducto(),
    );

    if (nuevoProducto != null) {
      await FirebaseFirestore.instance.collection('productos').add(nuevoProducto);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Producto guardado")),
      );
    }
  }

  void _registrarEntradaSalida(BuildContext context, String productoId, bool esEntrada) async {
    final productoRef = FirebaseFirestore.instance.collection('productos').doc(productoId);

    final doc = await productoRef.get();
    final stockActual = doc['stock'];

    final nuevaCantidad = esEntrada ? stockActual + 1 : stockActual - 1;

    if (nuevaCantidad >= 0) {
      // Actualizar el stock del producto
      await productoRef.update({'stock': nuevaCantidad});

      // Registrar el movimiento
      await FirebaseFirestore.instance.collection('movimientos').add({
        'productoId': productoId,
        'cantidad': esEntrada ? 1 : -1,
        'fecha': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(esEntrada ? "Entrada registrada!" : "Salida registrada!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡No hay suficiente stock!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productosRef = FirebaseFirestore.instance.collection('productos');

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: productosRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error cargando productos'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text('No hay productos'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final p = docs[index];
              final nombre = p['nombre'];
              final precio = p['precio'];
              final stock = (p.data() as Map<String, dynamic>).containsKey('stock') ? p['stock'] : 0;
              // Si no existe el stock, se asigna 0 por defecto

              return ListTile(
                leading: const Icon(Icons.inventory),
                title: Text(nombre),
                subtitle: Text("Precio: \$${precio.toStringAsFixed(2)} | Stock: $stock"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _registrarEntradaSalida(context, p.id, false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _registrarEntradaSalida(context, p.id, true),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _agregarProducto(context),
        child: const Icon(Icons.add),
        tooltip: 'Agregar producto',
      ),
    );
  }
}

class _DialogoAgregarProducto extends StatefulWidget {
  const _DialogoAgregarProducto();

  @override
  State<_DialogoAgregarProducto> createState() => _DialogoAgregarProductoState();
}

class _DialogoAgregarProductoState extends State<_DialogoAgregarProducto> {
  final nombreCtrl = TextEditingController();
  final precioCtrl = TextEditingController();
  final stockCtrl = TextEditingController();

  @override
  void dispose() {
    nombreCtrl.dispose();
    precioCtrl.dispose();
    stockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Nuevo Producto"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nombreCtrl,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          TextField(
            controller: precioCtrl,
            decoration: const InputDecoration(labelText: 'Precio en USD'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: stockCtrl,
            decoration: const InputDecoration(labelText: 'Stock Inicial'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (nombreCtrl.text.isNotEmpty &&
                precioCtrl.text.isNotEmpty &&
                stockCtrl.text.isNotEmpty) {
              Navigator.pop(context, {
                'nombre': nombreCtrl.text,
                'precio': double.tryParse(precioCtrl.text) ?? 0.0,
                'stock': int.tryParse(stockCtrl.text) ?? 0,
              });
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
