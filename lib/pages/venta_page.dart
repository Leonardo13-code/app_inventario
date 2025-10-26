// lib/pages/venta_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importación para formatos de entrada
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:InVen/services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VentaPage extends StatefulWidget {
  const VentaPage({super.key});

  @override
  State<VentaPage> createState() => _VentaPageState();
}

class _VentaPageState extends State<VentaPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  
  // Controladores y variables para datos de la factura
  final _formKey = GlobalKey<FormState>();
  // Valores por defecto para Consumidor Final
  final TextEditingController _clienteNombreCtrl = TextEditingController(text: 'Consumidor Final');
  final TextEditingController _clienteCedulaRifCtrl = TextEditingController(text: '0000000000');
  final TextEditingController _clienteDireccionCtrl = TextEditingController(text: 'Dirección no especificada');
  final TextEditingController _vendedorCtrl = TextEditingController(text: 'Vendedor 1');

  final List<Map<String, dynamic>> _selectedProducts = [];
  String _searchQuery = '';
  double _subtotalDolar = 0.0;
  double _impuestosDolar = 0.0;
  double _totalDolar = 0.0;
  double _tasaDolar = 0.0;
  final double _taxRate = 0.16;

  @override
  void initState() {
    super.initState();
    _fetchTasaDolar();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clienteNombreCtrl.dispose();
    _clienteCedulaRifCtrl.dispose();
    _clienteDireccionCtrl.dispose();
    _vendedorCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTasaDolar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tasaDolar = prefs.getDouble('tasa_dolar') ?? prefs.getDouble('dolar_bcv') ?? 0.0;
    });
  }

  void _calculateTotals() {
      double tempSubtotalGravable = 0.0;
      double tempSubtotalExento = 0.0;
      
      for (var product in _selectedProducts) {
          if (product['exento_iva'] == true) {
              tempSubtotalExento += product['subtotal'];
          } else {
              tempSubtotalGravable += product['subtotal'];
          }
      }
      
      double tempImpuestos = tempSubtotalGravable * _taxRate;
      double tempSubtotal = tempSubtotalGravable + tempSubtotalExento; // Subtotal es la suma de ambos
      double tempTotal = tempSubtotal + tempImpuestos;

      setState(() {
        _subtotalDolar = tempSubtotal;
        _impuestosDolar = tempImpuestos;
        _totalDolar = tempTotal;
      });
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

// Lógica para añadir producto por unidad o peso
void _addProduct(DocumentSnapshot productDoc) {
    final data = productDoc.data() as Map<String, dynamic>;
    final String productoId = productDoc.id;
    final String nombre = data['nombre'] ?? 'Desconocido';
    final int stockActual = (data['stock'] as num?)?.toInt() ?? 0;
    final double precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
    
    final bool esPorPeso = data['por_peso'] ?? false; 
    final bool esExentoIva = data['exento_iva'] ?? false; // NUEVO CAMPO
    
    if (stockActual <= 0) {
      _showSnackbar('Producto sin stock disponible.');
      return;
    }

    // Si es por unidad, aumenta 1 automáticamente si ya está en la lista
    if (!esPorPeso) {
      final existingIndex = _selectedProducts.indexWhere((p) => p['id'] == productoId);
      if (existingIndex != -1) {
        final int newQuantity = _selectedProducts[existingIndex]['cantidad'] + 1;
        if (newQuantity <= stockActual) {
          _selectedProducts[existingIndex]['cantidad'] = newQuantity;
          _selectedProducts[existingIndex]['subtotal'] = newQuantity * precio;
        } else {
          _showSnackbar('No hay suficiente stock disponible de este producto.');
        }
      } else {
        _selectedProducts.add({
          'id': productoId,
          'nombre': nombre,
          'precio': precio,
          'cantidad': 1.0,
          'subtotal': precio,
          'es_por_peso': false,
          'exento_iva': esExentoIva, // Guardar estado IVA
        });
      }
      _calculateTotals();
    } else {
      // Si es por peso, muestra el diálogo para ingresar la cantidad (Kg)
      _showQuantityDialog(productDoc, esPorPeso, stockActual);
    }
}

  void _showQuantityDialog(DocumentSnapshot productDoc, bool esPorPeso, int maxStock) {
    final data = productDoc.data() as Map<String, dynamic>;
    final String productoId = productDoc.id;
    final String nombre = data['nombre'] ?? 'Desconocido';
    final double precio = (data['precio'] as num?)?.toDouble() ?? 0.0;
    final bool esExentoIva = data['exento_iva'] ?? false; // Capturar estado IVA
    final TextEditingController quantityCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Ingresar Cantidad de $nombre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(esPorPeso ? 'Ingrese el peso en Kg (ej: 0.5 o 1.25)' : 'Ingrese la cantidad'),
              Text('Stock disponible: $maxStock ${esPorPeso ? 'Kg' : 'unidades'}', style: TextStyle(fontSize: 12, color: Colors.grey)),
              TextFormField(
                controller: quantityCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: esPorPeso ? 'Peso (Kg)' : 'Cantidad',
                ),
                validator: (value) {
                  final quantity = double.tryParse(value ?? '');
                  if (quantity == null || quantity <= 0) {
                    return 'Ingrese una cantidad válida.';
                  }
                  if (quantity > maxStock) {
                    return 'Excede el stock disponible ($maxStock ${esPorPeso ? 'Kg' : 'unidades'})';
                  }
                  return null;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
                child: const Text('Añadir'),
                onPressed: () {
                    final quantity = double.tryParse(quantityCtrl.text);
                    if (quantity != null && quantity > 0 && quantity <= maxStock) {
                        // PASAR EL NUEVO PARÁMETRO: esExentoIva
                        _addItemToList(productoId, nombre, precio, quantity, esPorPeso, esExentoIva); 
                        Navigator.of(context).pop();
                    } else {
                  // Muestra error dentro del diálogo si la validación falla
                  // Para un mejor UX, el validador del TextFormField debería manejar esto.
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _addItemToList(String id, String nombre, double precio, double cantidad, bool esPorPeso, bool esExentoIva) {
      final subtotal = cantidad * precio;
      final existingIndex = _selectedProducts.indexWhere((p) => p['id'] == id);

      if (existingIndex != -1) {
        _selectedProducts[existingIndex] = {
          'id': id,
          'nombre': nombre,
          'precio': precio,
          'cantidad': cantidad,
          'subtotal': subtotal,
          'es_por_peso': esPorPeso,
          'exento_iva': esExentoIva, // Guardar estado IVA
        };
      } else {
        _selectedProducts.add({
          'id': id,
          'nombre': nombre,
          'precio': precio,
          'cantidad': cantidad,
          'subtotal': subtotal,
          'es_por_peso': esPorPeso,
          'exento_iva': esExentoIva, // Guardar estado IVA
        });
      }
      _calculateTotals();
  }

  void _updateProductQuantity(int index, double newQuantity, int maxStock) {
    if (newQuantity > 0 && newQuantity <= maxStock) {
      _selectedProducts[index]['cantidad'] = newQuantity;
      _selectedProducts[index]['subtotal'] = newQuantity * _selectedProducts[index]['precio'];
      _calculateTotals();
    } else if (newQuantity <= 0) {
      _selectedProducts.removeAt(index);
      _calculateTotals();
    } else {
      _showSnackbar('No puedes seleccionar más de la cantidad de stock disponible.');
    }
  }

  Future<void> _confirmSale() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Por favor, complete los datos del cliente y vendedor.');
      return;
    }
    if (_selectedProducts.isEmpty) {
      _showSnackbar('El pedido está vacío.');
      return;
    }

    final WriteBatch batch = FirebaseFirestore.instance.batch();

    try {
      // 1. Actualizar el stock de cada producto
      for (var item in _selectedProducts) {
        final docRef = FirebaseFirestore.instance.collection('productos').doc(item['id']);
        final currentStock = (await docRef.get()).data()?['stock'] as num;
        
        // Se usa la cantidad (que puede ser decimal) para el descuento
        final double newStock = currentStock.toDouble() - (item['cantidad'] as num).toDouble(); 
        
        if (newStock < 0) {
          throw Exception('Stock insuficiente para ${item['nombre']}');
        }

        // Se guarda el stock como double en Firestore (aunque se haya iniciado como int)
        batch.update(docRef, {'stock': newStock}); 
      }

      // 2. Registrar la venta con datos completos de facturación
      final ventaData = {
        'fecha': Timestamp.now(),
        'totalDolar': _totalDolar,
        'totalBolivar': _totalDolar * _tasaDolar,
        'subtotalDolar': _subtotalDolar,
        'impuestosDolar': _impuestosDolar,
        'tasaDolar': _tasaDolar,
        
        'clienteNombre': _clienteNombreCtrl.text.trim(),
        'clienteCedulaRif': _clienteCedulaRifCtrl.text.trim(),
        'clienteDireccion': _clienteDireccionCtrl.text.trim(),
        'vendedor': _vendedorCtrl.text.trim(),
        
        'productos': _selectedProducts.map((p) => {
              'id': p['id'],
              'nombre': p['nombre'],
              'cantidad': p['cantidad'],
              'es_por_peso': p['es_por_peso'],
              'exento_iva': p['exento_iva'], // NUEVO CAMPO GUARDADO
              'precioUnitario': p['precio'],
              'subtotal': p['subtotal'],
            }).toList(),
      };
      batch.set(FirebaseFirestore.instance.collection('ventas').doc(), ventaData);

      // 3. Confirmar todas las operaciones atómicamente
      await batch.commit();

      _showSnackbar('Venta registrada con éxito.', isError: false);
      
      // Limpiar el carrito y restablecer datos del cliente/vendedor
      setState(() {
        _selectedProducts.clear();
        _calculateTotals();
        _clienteNombreCtrl.text = 'Consumidor Final'; 
        _clienteCedulaRifCtrl.text = '0000000000'; 
        _clienteDireccionCtrl.text = 'Dirección no especificada';
      });

    } catch (e) {
      _showSnackbar('Error al procesar la venta: $e');
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nuevo Pedido',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      // FIX CLAVE 1: Envuelve el cuerpo en SingleChildScrollView para permitir desplazamiento.
      body: SingleChildScrollView( 
        child: Column(
          children: [
            // Sección de Datos de Facturación (Ocultable)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ExpansionTile(
                  title: const Text('Datos del Cliente y Vendedor'),
                  leading: const Icon(Icons.person),
                  initiallyExpanded: false,
                  children: [
                    TextFormField(
                      controller: _clienteNombreCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre o Razón Social'),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    TextFormField(
                      controller: _clienteCedulaRifCtrl,
                      decoration: const InputDecoration(labelText: 'Cédula de Identidad / RIF'),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    TextFormField(
                      controller: _clienteDireccionCtrl,
                      decoration: const InputDecoration(labelText: 'Dirección Fiscal'),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    TextFormField(
                      controller: _vendedorCtrl,
                      decoration: const InputDecoration(labelText: 'Vendedor Atendió'),
                      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            
            // Sección de búsqueda de productos
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Buscar producto',
                  suffixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(15.0)),
                  ),
                ),
              ),
            ),
            // FIX CLAVE 2: Usar SizedBox con altura fija en lugar de Expanded
            SizedBox(
              height: 250, // Altura limitada para la lista de productos disponibles
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getCollection('productos', orderByField: 'nombre').snapshots(),
                builder: (context, snapshot) {
                  // ... (lógica de manejo de errores y carga)
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay productos disponibles.'));

                  final products = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = data['nombre']?.toString().toLowerCase() ?? '';
                    return nombre.contains(_searchQuery.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final data = product.data() as Map<String, dynamic>;
                      final nombre = data['nombre'] ?? 'Desconocido';
                      final stock = (data['stock'] as num?)?.toDouble() ?? 0.0; // Cambiado a double
                      final precioDolar = (data['precio'] as num?)?.toDouble() ?? 0.0;
                      final precioBolivar = precioDolar * _tasaDolar;
                      final esPorPeso = data['por_peso'] ?? false; // Nuevo campo

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                        child: ListTile(
                          leading: Icon(esPorPeso ? Icons.scale : Icons.inventory, color: Colors.blueAccent),
                          title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Stock: ${stock.toStringAsFixed(esPorPeso ? 2 : 0)} ${esPorPeso ? 'Kg' : 'unidades'}'),
                              Text('Precio: \$${precioDolar.toStringAsFixed(2)} ${esPorPeso ? '/Kg' : '/u'}'),
                              if (_tasaDolar > 0)
                                Text('(${NumberFormat.currency(locale: 'es_VE', symbol: 'Bs').format(precioBolivar)} ${esPorPeso ? '/Kg' : '/u'})'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_shopping_cart, color: Colors.blueAccent),
                            onPressed: stock > 0 ? () => _addProduct(product) : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Sección del carrito/pedido (Fija) - Contenedor principal del carrito
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Detalle del Pedido',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_selectedProducts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('Aún no hay productos en el carrito.'),
                    ),
                  // FIX CLAVE 3: La lista de productos seleccionados tiene alto fijo y es scrollable
                  SizedBox(
                    height: 150, // Altura máxima fija de 150 píxeles
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(), // Permite el scroll
                      itemCount: _selectedProducts.length,
                      itemBuilder: (context, index) {
                        final product = _selectedProducts[index];
                        final String productoId = product['id'];

                        return FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('productos').doc(productoId).get(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return const SizedBox.shrink();
                            }
                            final data = snapshot.data!.data() as Map<String, dynamic>;
                            final double maxStock = (data['stock'] as num?)?.toDouble() ?? 0.0;
                            final bool esPorPeso = product['es_por_peso'];

                            return Card(
                              color: Colors.blue.shade50,
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              child: ListTile(
                                title: Text(
                                  '${product['nombre']} x${product['cantidad'].toStringAsFixed(esPorPeso ? 2 : 0)} ${esPorPeso ? 'Kg' : 'u'}',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('\$${product['subtotal'].toStringAsFixed(2)}'),
                                    if (_tasaDolar > 0)
                                      Text('(${NumberFormat.currency(locale: 'es_VE', symbol: 'Bs').format(product['subtotal'] * _tasaDolar)})'),
                                  ],
                                ),
                                trailing: esPorPeso
                                    ? IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _updateProductQuantity(index, 0, maxStock.toInt()),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline),
                                            onPressed: () {
                                              _updateProductQuantity(index, product['cantidad'].toDouble() - 1, maxStock.toInt());
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline),
                                            onPressed: () {
                                              _updateProductQuantity(index, product['cantidad'].toDouble() + 1, maxStock.toInt());
                                            },
                                          ),
                                        ],
                                      ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Totales
                  _buildTotalRow('Subtotal', _subtotalDolar),
                  _buildTotalRow('Impuestos (16%)', _impuestosDolar),
                  const Divider(),
                  _buildTotalRow('Total', _totalDolar, isBold: true),
                  const SizedBox(height: 10),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _selectedProducts.isNotEmpty ? _confirmSale : null,
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Confirmar Pedido', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double dolarValue, {bool isBold = false}) {
    // ... (Tu función _buildTotalRow permanece igual)
    final style = TextStyle(
      fontSize: isBold ? 18 : 16,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    final bolivarValue = dolarValue * _tasaDolar;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${dolarValue.toStringAsFixed(2)}', style: style),
              if (_tasaDolar > 0)
                Text(
                  NumberFormat.currency(locale: 'es_VE', symbol: 'Bs').format(bolivarValue),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }
}