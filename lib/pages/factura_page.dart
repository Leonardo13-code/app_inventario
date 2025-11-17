// lib/pages/factura_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FacturaPage extends StatelessWidget {
  final List<Map<String, dynamic>> productos;
  final double subtotalDolar;
  final double impuestosDolar;
  final double totalDolar;
  final double tasaDolar;

  const FacturaPage({
    super.key,
    required this.productos,
    required this.subtotalDolar,
    required this.impuestosDolar,
    required this.totalDolar,
    required this.tasaDolar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Factura de Venta',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recibo de Venta',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const Divider(height: 20, thickness: 2),
                _buildFacturaInfo(),
                const Divider(height: 20),
                _buildProductosTable(),
                const Divider(height: 20),
                _buildTotalesSection(),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Lógica para generar y compartir el PDF
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Generando factura en PDF...')),
                      );
                    },
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text('Generar PDF', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFacturaInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          style: const TextStyle(fontSize: 14),
        ),
        const Text(
          'Cliente: Público General',
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildProductosTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detalles del Producto',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildTableHeader(),
        const Divider(height: 1, thickness: 1),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: productos.length,
          itemBuilder: (context, index) {
            final product = productos[index];
            return _buildTableRow(
              product['nombre'],
              '${product['cantidad']}',
              '${product['precio'].toStringAsFixed(2)}',
              '${product['subtotal'].toStringAsFixed(2)}',
            );
          },
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 1, child: Text('Cant.', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('P.U.', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTableRow(String producto, String cantidad, String precio, String total) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(producto)),
          Expanded(flex: 1, child: Text(cantidad, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('\$$precio', textAlign: TextAlign.end)),
          Expanded(flex: 2, child: Text('\$$total', textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildTotalesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildTotalRow('Subtotal', subtotalDolar),
        _buildTotalRow('Impuestos (16%)', impuestosDolar),
        const Divider(),
        _buildTotalRow('Total', totalDolar, isBold: true),
        if (tasaDolar > 0)
          Text(
            '(${NumberFormat.currency(locale: 'es_VE', symbol: 'Bs').format(totalDolar * tasaDolar)})',
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double dolarValue, {bool isBold = false}) {
    final style = TextStyle(
      fontSize: isBold ? 18 : 16,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('\$${dolarValue.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}