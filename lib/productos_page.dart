import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductosPage extends StatefulWidget {
  const ProductosPage({super.key});

  @override
  State<ProductosPage> createState() => _ProductosPageState();
}

class _ProductosPageState extends State<ProductosPage> {
  double? tasaBCV;

  @override
  void initState() {
    super.initState();
    _cargarTasaBCV();
  }

  Future<void> _cargarTasaBCV() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tasaBCV = prefs.getDouble('tasa_bcv') ?? 0.0;
    });
  }

  void _agregarProducto() async {
    final nuevoProducto = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _DialogoAgregarProducto(),
    );

    if (nuevoProducto != null) {
      await FirebaseFirestore.instance.collection('productos').add(nuevoProducto);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Producto guardado")),
        );
      }
    }
  }

  Future<void> _registrarEntradaSalida(String productoId, bool esEntrada) async {
    final productoRef = FirebaseFirestore.instance.collection('productos').doc(productoId);

    final doc = await productoRef.get();
    final stockActual = doc['stock'];

    final nuevaCantidad = esEntrada ? stockActual + 1 : stockActual - 1;

    if (nuevaCantidad >= 0) {
      await productoRef.update({'stock': nuevaCantidad});

      await FirebaseFirestore.instance.collection('movimientos').add({
        'productoId': productoId,
        'cantidad': esEntrada ? 1 : -1,
        'fecha': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(esEntrada ? "Entrada registrada!" : "Salida registrada!")),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡No hay suficiente stock!")),
        );
      }
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
              final precioUSD = p['precio'] is int
                  ? (p['precio'] as int).toDouble()
                  : p['precio'] ?? 0.0;
              final stock = (p.data() as Map<String, dynamic>).containsKey('stock') ? p['stock'] : 0;

              final precioBs = tasaBCV != null && tasaBCV! > 0
                  ? precioUSD * tasaBCV!
                  : 0.0;

              final stockBajo = stock <= 5;

              return ListTile(
                leading: const Icon(Icons.inventory),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nombre,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (stockBajo)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.warning, color: Colors.red, size: 18),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Precio: \$${precioUSD.toStringAsFixed(2)} | Bs ${precioBs.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: stockBajo ? Colors.red : Colors.black,
                      ),
                    ),
                    Text("Stock: $stock"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _registrarEntradaSalida(p.id, false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green),
                      onPressed: () => _registrarEntradaSalida(p.id, true),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _agregarProducto,
        tooltip: 'Agregar producto',
        child: const Icon(Icons.add),
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

  double? tasaBCV;
  double precioBs = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarTasaBCV();
    precioCtrl.addListener(_actualizarPrecioBs);
  }

  Future<void> _cargarTasaBCV() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tasaBCV = prefs.getDouble('tasa_bcv') ?? 0.0;
    });
  }

  void _actualizarPrecioBs() {
    final precioUSD = double.tryParse(precioCtrl.text) ?? 0.0;
    if (tasaBCV != null) {
      setState(() {
        precioBs = precioUSD * tasaBCV!;
      });
    }
  }

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
          if (tasaBCV != null && tasaBCV! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Precio en Bs: ${precioBs.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                ),
              ),
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
