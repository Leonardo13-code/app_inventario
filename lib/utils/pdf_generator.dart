// lib/utils/pdf_generator.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Modelo simplificado para los datos de la factura
class InvoiceData {
  final String id;
  final DateTime fecha;
  final double totalDolar;
  final double totalBolivar;
  final double subtotalDolar;
  final double impuestosDolar;
  final double tasaDolar;
  final String clienteNombre;
  final String clienteCedulaRif;
  final String clienteDireccion;
  final String vendedor;
  final List<Map<String, dynamic>> productos;

  InvoiceData.fromFirestore(DocumentSnapshot doc)
      : id = doc.id,
        fecha = (doc['fecha'] as Timestamp).toDate(),
        totalDolar = (doc['totalDolar'] as num).toDouble(),
        totalBolivar = (doc['totalBolivar'] as num).toDouble(),
        subtotalDolar = (doc['subtotalDolar'] as num).toDouble(),
        impuestosDolar = (doc['impuestosDolar'] as num).toDouble(),
        tasaDolar = (doc['tasaDolar'] as num).toDouble(),
        clienteNombre = doc['clienteNombre'] as String,
        clienteCedulaRif = doc['clienteCedulaRif'] as String,
        clienteDireccion = doc['clienteDireccion'] as String,
        vendedor = doc['vendedor'] as String,
        productos = (doc['productos'] as List<dynamic>).map((item) => item as Map<String, dynamic>).toList(); 
}

class PdfInvoiceGenerator {
  // --- INFORMACIÓN DEL NEGOCIO ---
  static const String businessName = 'TU NEGOCIO DE INVENTARIO C.A.';
  static const String businessRif = 'J-00000000-0';
  static const String businessAddress = 'Calle Principal, Edificio X, Ciudad, Estado';
  // --------------------------------------------------------------------------

  // Función principal para crear el PDF
  static Future<Uint8List> generateInvoice(InvoiceData data) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Encabezado del Negocio
              _buildHeader(data, boldFont),
              pw.SizedBox(height: 20),

              // 2. Datos del Cliente
              _buildCustomerInfo(data, font, boldFont),
              pw.SizedBox(height: 20),

              // 3. Detalles de la Compra (Tabla)
              _buildItemsTable(data, font, boldFont),
              pw.SizedBox(height: 20),

              // 4. Totales
              _buildTotals(data, font, boldFont),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(InvoiceData data, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(businessName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: boldFont)),
        pw.Text('RIF: $businessRif', style: const pw.TextStyle(fontSize: 12)),
        pw.Text('Dirección: $businessAddress', style: const pw.TextStyle(fontSize: 12)),
        pw.Divider(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Factura N°: ${data.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont)),
                pw.Text('Fecha: ${DateFormat('dd/MM/yyyy').format(data.fecha)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Hora: ${DateFormat('hh:mm a').format(data.fecha)}', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
            pw.Text(
              'TASA BCV: Bs. ${data.tasaDolar.toStringAsFixed(2)} / \$',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800, font: boldFont),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildCustomerInfo(InvoiceData data, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Datos del Cliente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: boldFont)),
          pw.SizedBox(height: 5),
          _buildInfoRow('Nombre/Razón Social:', data.clienteNombre, font, boldFont),
          _buildInfoRow('C.I./RIF:', data.clienteCedulaRif, font, boldFont),
          _buildInfoRow('Dirección Fiscal:', data.clienteDireccion, font, boldFont),
          _buildInfoRow('Vendedor Atendió:', data.vendedor, font, boldFont),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Row(
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, font: boldFont)),
        pw.SizedBox(width: 5),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, font: font)),
      ],
    );
  }

  static pw.Widget _buildItemsTable(InvoiceData data, pw.Font font, pw.Font boldFont) {
    const tableHeaders = ['Artículos', 'Cant.', 'P/Unit (\$)', 'IVA', 'Total (\$)', 'Total (Bs)'];

    final tableRows = data.productos.map((item) {
      // Las variables que estaban obsoletas o sin usar se eliminaron de aquí.
      final totalBolivar = item['subtotal'] * data.tasaDolar;
      final bool esExentoIva = item['exento_iva'] ?? false; // Capturar el estado IVA del item

      return [
        item['nombre'].toString(),
        // Mostrar cantidad con 0 o 2 decimales según si es por peso
        item['cantidad'].toStringAsFixed(item['es_por_peso'] == true ? 2 : 0), 
        item['precioUnitario'].toStringAsFixed(2),
        esExentoIva ? 'EXENTO' : '16%', // Columna IVA
        item['subtotal'].toStringAsFixed(2),
        NumberFormat.currency(locale: 'es_VE', symbol: '').format(totalBolivar),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: tableHeaders,
      data: tableRows,
      border: pw.TableBorder.all(color: PdfColors.grey400),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: boldFont),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      cellStyle: pw.TextStyle(fontSize: 10, font: font),
      cellAlignment: pw.Alignment.centerRight,
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FlexColumnWidth(1.8),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        3: pw.Alignment.center,
      },
    );
}

static pw.Widget _buildTotals(InvoiceData data, pw.Font font, pw.Font boldFont) {
    final double subtotalGravable = data.subtotalDolar - (data.impuestosDolar / 0.16); // Recalcula el Subtotal Gravable
    final double subtotalExento = data.subtotalDolar - subtotalGravable; // Recalcula el Subtotal Exento
    final totalBs = data.totalBolivar;

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          // Mostrar desglosado: Subtotal Exento y Subtotal Gravable
          _buildTotalRow('Subtotal Exento (\$):', subtotalExento, boldFont, isDollar: true),
          _buildTotalRow('Subtotal Gravable (\$):', subtotalGravable, boldFont, isDollar: true),
          _buildTotalRow('Impuestos (16%) (\$):', data.impuestosDolar, boldFont, isDollar: true),
          pw.Divider(),
          _buildTotalRow('TOTAL (\$):', data.totalDolar, boldFont, isDollar: true, isFinal: true),
          _buildTotalRow('TOTAL (Bs):', totalBs, boldFont, isDollar: false, isFinal: true),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, double value, pw.Font boldFont, {required bool isDollar, bool isFinal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: isFinal ? 14 : 12,
              font: boldFont,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Container(
            width: 100,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              isDollar
                  ? '\$${value.toStringAsFixed(2)}'
                  : NumberFormat.currency(locale: 'es_VE', symbol: 'Bs. ').format(value),
              style: pw.TextStyle(
                fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: isFinal ? 14 : 12,
                color: isFinal ? PdfColors.green800 : PdfColors.black,
                font: boldFont,
              ),
            ),
          ),
        ],
      ),
    );
  }
}