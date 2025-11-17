// lib/pages/historial_ventas_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart'; 
import 'package:InVen/utils/pdf_generator.dart'; 

class HistorialVentasPage extends StatefulWidget {
  const HistorialVentasPage({super.key});

  @override
  State<HistorialVentasPage> createState() => _HistorialVentasPageState();
}

class _HistorialVentasPageState extends State<HistorialVentasPage> {
  final String _collectionName = 'ventas';

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  
  // --- VALIDACIÓN DE CONTRASEÑA ---

  Future<bool> _validarCredenciales(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay un usuario autenticado para validar.')),
        );
      }
      return false;
    }

    String? password;
    final String userEmail = user.email!;
    
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmación de Seguridad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Por seguridad, ingrese su contraseña para confirmar la eliminación de historial de ventas ($userEmail):'),
              const SizedBox(height: 10),
              TextField(
                onChanged: (value) => password = value,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (password != null && password!.isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || password == null) return false;

    try {
      final credential = EmailAuthProvider.credential(email: userEmail, password: password!);
      await user.reauthenticateWithCredential(credential);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales validadas. Procediendo a eliminar.')),
        );
      }
      return true; 
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Error de autenticación. Contraseña incorrecta.';
        if (e.code == 'wrong-password') {
          message = 'Contraseña incorrecta. Intente de nuevo.';
        } else if (e.code == 'user-disabled') {
          message = 'El usuario ha sido deshabilitado.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return false; 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado al reautenticar: ${e.toString()}')),
        );
      }
      return false;
    }
  }

  // --- MÉTODOS DE GESTIÓN DE LIMPIEZA ---
  
  Future<void> _seleccionarFecha(BuildContext context, bool esFechaInicio) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final DateTime adjustedDate = esFechaInicio
          ? picked.copyWith(hour: 0, minute: 0, second: 0, microsecond: 0, millisecond: 0)
          : picked.copyWith(hour: 23, minute: 59, second: 59, microsecond: 999, millisecond: 999);
      
      if (context.mounted) {
        if (esFechaInicio) {
          _selectedStartDate = adjustedDate;
        } else {
          _selectedEndDate = adjustedDate;
        }
      }
    }
  }

  void _mostrarDialogoLimpieza() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (contextInternal, setStateInternal) {
            return AlertDialog(
              title: const Text('Limpieza de Historial de Ventas'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleccione el rango de fechas para la eliminación PERMANENTE de ventas:'),
                  const SizedBox(height: 15),

                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _selectedStartDate == null
                          ? 'Fecha de Inicio'
                          : 'Desde: ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)}',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      await _seleccionarFecha(contextInternal, true);
                      setStateInternal(() {});
                    },
                  ),
                  
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: Text(
                      _selectedEndDate == null
                          ? 'Fecha de Fin'
                          : 'Hasta: ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () async {
                      await _seleccionarFecha(contextInternal, false);
                      setStateInternal(() {});
                    },
                  ),
                  
                  if (_selectedStartDate != null && _selectedEndDate != null && _selectedStartDate!.isAfter(_selectedEndDate!))
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'La fecha de inicio no puede ser posterior a la fecha de fin.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  onPressed: (_selectedStartDate == null || 
                              _selectedEndDate == null ||
                              _selectedStartDate!.isAfter(_selectedEndDate!))
                      ? null
                      : () {
                          // Cerramos el diálogo antes de la operación async
                          Navigator.pop(dialogContext);
                          // Iniciamos el proceso de doble confirmación
                          _iniciarProcesoEliminacion(context);
                        },
                  icon: const Icon(Icons.delete_forever, color: Colors.white),
                  label: const Text('Eliminar Historial', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- PROCESO SECUENCIAL ---
  Future<void> _iniciarProcesoEliminacion(BuildContext parentContext) async {
    // 1. Validar contraseña
    final bool credencialesValidas = await _validarCredenciales(parentContext);

    if (!credencialesValidas) return; // Si la contraseña es incorrecta, salimos.
    
    // 2. Si la contraseña es válida, procedemos a la confirmación de rango y eliminación
    _confirmarYEliminar(parentContext);
  }
  // ----------------------------------------

  Future<void> _confirmarYEliminar(BuildContext parentContext) async {
    if (_selectedStartDate == null || _selectedEndDate == null) return;
    
    final countSnapshot = await FirebaseFirestore.instance
        .collection(_collectionName)
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(_selectedStartDate!))
        .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(_selectedEndDate!))
        .count()
        .get();

    final int count = countSnapshot.count ?? 0;
    
    if (!mounted) return;
    
    // Si el contador es 0, no continuamos y notificamos al usuario.
    if (count == 0) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(content: Text('No se encontraron registros de ventas en el rango seleccionado. Nada que eliminar.')),
        );
        setState(() {
            _selectedStartDate = null;
            _selectedEndDate = null;
        });
        return; 
    }
    
    final bool? confirmar = await showDialog<bool>(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('¡ADVERTENCIA! Eliminación Masiva'),
        content: Text(
          'Se eliminarán PERMANENTEMENTE $count registros de ventas '
          'registrados entre el ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)} y el ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}.\n\n'
          'Esta acción NO es reversible. ¿Desea continuar?',
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Eliminar Ahora', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    
    if (confirmar == true) {
      try {
        await _batchDeleteDocuments(_collectionName, _selectedStartDate!, _selectedEndDate!);
        if (mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(content: Text('Se eliminaron $count registros de ventas correctamente.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(content: Text('Error al eliminar: ${e.toString()}')),
          );
        }
      }
    }
    if (mounted) {
        setState(() {
            _selectedStartDate = null;
            _selectedEndDate = null;
        });
    }
  }

  Future<void> _batchDeleteDocuments(String collection, DateTime startDate, DateTime endDate) async {
    QuerySnapshot snapshot;
    
    do {
      snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('fecha', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .limit(500)
          .get();

      if (snapshot.docs.isNotEmpty) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } while (snapshot.docs.isNotEmpty);
  }

  void _openPdfPreview(DocumentSnapshot ventaDoc) async {
    try {
      final InvoiceData data = InvoiceData.fromFirestore(ventaDoc); 
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => PdfInvoiceGenerator.generateInvoice(data),
        name: 'Factura_${data.id.substring(0, 8).toUpperCase()}.pdf',
      );
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar la factura: $e')),
        );
      }
    }
  }
  
  // --- BUILD METHOD ---

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
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services, color: Colors.white),
            tooltip: 'Limpiar Historial de Ventas',
            onPressed: _mostrarDialogoLimpieza,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(_collectionName)
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
                  onTap: () => _openPdfPreview(ventaDoc),
                ),
              );
            },
          );
        },
      ),
    );
  }
}