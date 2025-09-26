// lib/pages/historial_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:app_inventario/services/firestore_service.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de Movimientos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orangeAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Código corregido: eliminamos el parámetro 'descending' que causaba el error.
        stream: _firestoreService.getCollection('movimientos', orderByField: 'fecha').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  const Text(
                    'No hay movimientos registrados.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final movimientos = snapshot.data!.docs;
          
          // Agrupar movimientos por fecha para la clasificación por día
          Map<String, List<DocumentSnapshot>> groupedMovimientos = {};
          for (var doc in movimientos) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final Timestamp? timestamp = data['fecha'] as Timestamp?;
            if (timestamp == null) continue;
            
            final DateTime date = timestamp.toDate();
            final String formattedDate = DateFormat('dd MMMM yyyy').format(date);

            if (!groupedMovimientos.containsKey(formattedDate)) {
              groupedMovimientos[formattedDate] = [];
            }
            groupedMovimientos[formattedDate]!.add(doc);
          }

          List<MapEntry<String, List<DocumentSnapshot>>> sortedGroups = groupedMovimientos.entries.toList()
            ..sort((a, b) => DateFormat('dd MMMM yyyy').parse(b.key).compareTo(DateFormat('dd MMMM yyyy').parse(a.key)));

          return ListView.builder(
            itemCount: sortedGroups.length,
            itemBuilder: (context, groupIndex) {
              final group = sortedGroups[groupIndex];
              final String groupDate = group.key;
              final List<DocumentSnapshot> groupDocs = group.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                    child: Text(
                      groupDate,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupDocs.length,
                    itemBuilder: (context, itemIndex) {
                      final mov = groupDocs[itemIndex].data() as Map<String, dynamic>? ?? {};

                      final tipo = mov['tipo'] ?? 'Desconocido';
                      final cantidad = (mov['cantidad'] as num?)?.toInt() ?? 0;
                      final productoNombre = mov['productoNombre'] ?? 'Producto Desconocido';
                      final usuario = mov['usuario'] ?? 'Anónimo';
                      final ubicacion = mov['ubicacion'] ?? 'No especificada';
                      final motivo = mov['motivo'] ?? 'No especificado';
                      final fecha = (mov['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
                      
                      final isEntrada = tipo == 'Entrada';
                      final color = isEntrada ? Colors.green.shade100 : Colors.red.shade100;
                      final icon = isEntrada ? Icons.add_circle : Icons.remove_circle;
                      final iconColor = isEntrada ? Colors.green.shade800 : Colors.red.shade800;

                      return Card(
                        color: color,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: Icon(icon, color: iconColor, size: 40),
                          title: Text(
                            productoNombre,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Tipo: $tipo'),
                              Text('Cantidad: $cantidad'),
                              Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'),
                              Text('Usuario: $usuario'),
                              Text('Ubicación: $ubicacion'),
                              Text('Motivo: $motivo'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}