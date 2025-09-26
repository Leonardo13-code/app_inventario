// lib/pages/historial_ventas_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart'; // ¡Importación necesaria para PdfPageFormat!
import 'package:app_inventario/utils/pdf_generator.dart'; // Asumiendo que esta ruta es correcta

class HistorialVentasPage extends StatefulWidget {
  const HistorialVentasPage({super.key});

  @override
  State<HistorialVentasPage> createState() => _HistorialVentasPageState();
}

class _HistorialVentasPageState extends State<HistorialVentasPage> {
  
  // Función para previsualizar y generar el PDF
  void _openPdfPreview(DocumentSnapshot ventaDoc) async {
    try {
      final InvoiceData data = InvoiceData.fromFirestore(ventaDoc);
      
      // Abre la vista previa del PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => PdfInvoiceGenerator.generateInvoice(data),
        name: 'Factura_${data.id.substring(0, 8).toUpperCase()}.pdf',
      );
      
    } catch (e) {
      if (mounted) {
        // Se usa mounted para asegurar que el uso de context es seguro después del await.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar la factura: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de Ventas',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ventas')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Aún no hay ventas registradas.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final ventaDoc = snapshot.data!.docs[index];
              final data = ventaDoc.data() as Map<String, dynamic>;

              final totalDolar = (data['totalDolar'] as num?)?.toDouble() ?? 0.0;
              final totalBolivar = (data['totalBolivar'] as num?)?.toDouble() ?? 0.0;
              final tasaDolar = (data['tasaDolar'] as num?)?.toDouble() ?? 0.0;
              final fecha = (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                elevation: 4,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16.0),
                  leading: const Icon(Icons.receipt_long, color: Colors.indigo, size: 40),
                  title: Text(
                    // Mostramos el ID de la venta como N° de factura
                    'Factura N° ${ventaDoc.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Fecha: ${DateFormat('dd/MM/yyyy - hh:mm a').format(fecha)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        'Cliente: ${data['clienteNombre'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        'Tasa Utilizada: Bs ${tasaDolar.toStringAsFixed(2)}/\$',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'TOTAL: \$${totalDolar.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                      ),
                      Text(
                        'Equivalente: ${NumberFormat.currency(locale: 'es_VE', symbol: 'Bs').format(totalBolivar)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.indigo),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.print, color: Colors.blue),
                  onTap: () => _openPdfPreview(ventaDoc), // Llama a la función de generación de PDF
                ),
              );
            },
          );
        },
      ),
    );
  }
}