// lib/pages/historial_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para formatear fechas
import 'package:app_inventario/services/firestore_service.dart'; // Importar el servicio

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final FirestoreService _firestoreService = FirestoreService();

  // Aquí prepararemos variables para futuros filtros
  // String _selectedFilter = 'Todos';
  // DateTime? _selectedStartDate;
  // DateTime? _selectedEndDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de Movimientos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orangeAccent, // Color de la barra de app
        iconTheme: const IconThemeData(color: Colors.white), // Color del ícono de retroceso
        // Aquí podríamos añadir acciones para filtros en el futuro
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              // Lógica para mostrar filtros (futura implementación)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Opciones de filtro en desarrollo.")),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>( // Aseguramos el tipo del StreamBuilder
        // Usando el servicio de Firestore para obtener los movimientos
        stream: _firestoreService.getCollection(
          'movimientos',
          orderByField: 'fecha',
        ).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final movimientos = snapshot.data!.docs;

          if (movimientos.isEmpty) {
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

          // Agrupar movimientos por fecha para la clasificación por día
          Map<String, List<DocumentSnapshot<Map<String, dynamic>>>> groupedMovimientos = {}; // Especificar el tipo de DocumentSnapshot
          for (var doc in movimientos) {
            // CORRECCIÓN 1: Manejar el caso en que doc.data() sea nulo
            final data = doc.data() ?? {}; // Si es nulo, usa un mapa vacío
            final Timestamp? timestamp = data['fecha'] as Timestamp?; // Usar 'Timestamp?' para permitir nulos
            
            if (timestamp == null) continue; // Si la fecha es nula, saltar este movimiento
            
            final DateTime date = timestamp.toDate();
            final String formattedDate = DateFormat('dd MMMM yyyy').format(date);

            if (!groupedMovimientos.containsKey(formattedDate)) {
              groupedMovimientos[formattedDate] = [];
            }
            groupedMovimientos[formattedDate]!.add(doc);
          }

          // Convertir el mapa a una lista de entradas para mantener el orden
          List<MapEntry<String, List<DocumentSnapshot<Map<String, dynamic>>>>> sortedGroups = groupedMovimientos.entries.toList()
            ..sort((a, b) => DateFormat('dd MMMM yyyy').parse(b.key).compareTo(DateFormat('dd MMMM yyyy').parse(a.key))); // Ordenar los grupos por fecha (más reciente primero)


          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: sortedGroups.length,
            itemBuilder: (context, groupIndex) {
              final group = sortedGroups[groupIndex];
              final String groupDate = group.key;
              final List<DocumentSnapshot<Map<String, dynamic>>> groupDocs = group.value; // Especificar el tipo

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 5.0),
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
                    shrinkWrap: true, // Para que el ListView interno se ajuste al contenido
                    physics: const NeverScrollableScrollPhysics(), // Deshabilita el scroll del ListView interno
                    itemCount: groupDocs.length,
                    itemBuilder: (context, itemIndex) {
                      // CORRECCIÓN 2: Manejar el caso en que .data() sea nulo
                      final Map<String, dynamic> mov = groupDocs[itemIndex].data() ?? {};
                      
                      final String productoId = mov['productoId'] ?? 'ID no disponible';
                      final int cantidad = (mov['cantidad'] as num?)?.toInt() ?? 0;
                      final Timestamp? fechaTimestamp = mov['fecha'] as Timestamp?; // Permitir nulo
                      final DateTime fecha = fechaTimestamp?.toDate() ?? DateTime.now(); // Si es nulo, usa la fecha actual
                      final String tipoMovimiento = cantidad > 0 ? 'Entrada' : 'Salida';
                      final String usuario = mov['usuario'] ?? 'N/A';
                      final String motivo = mov['motivo'] ?? 'Sin motivo';
                      final String documento = mov['documento'] ?? 'N/A';
                      final String ubicacion = mov['ubicacion'] ?? 'N/A';


                      // Para obtener el nombre del producto, necesitamos una FutureBuilder aquí,
                      // o precargar los nombres si fuera posible.
                      // Por eficiencia, es mejor si "nombreProducto" también se guarda en "movimientos"
                      // en la entrada/salida, para evitar una lectura adicional por cada movimiento.
                      // Si no está, lo buscaremos, pero es menos eficiente.
                      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>( // Especificar el tipo de DocumentSnapshot
                        future: _firestoreService.getDocument('productos', productoId),
                        builder: (context, snapshotProducto) {
                          String nombreProducto = 'Cargando...';
                          if (snapshotProducto.connectionState == ConnectionState.done && snapshotProducto.hasData) {
                            // CORRECCIÓN 3: Manejar el caso en que .data() sea nulo
                            nombreProducto = (snapshotProducto.data?.data() ?? {})['nombre'] ?? 'Producto Desconocido';
                          } else if (snapshotProducto.hasError) {
                            nombreProducto = 'Error producto';
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 5.0),
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        nombreProducto,
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blueGrey[800],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cantidad > 0 ? Colors.green.shade100 : Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tipoMovimiento,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: cantidad > 0 ? Colors.green[700] : Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Cantidad: ${cantidad > 0 ? '+' : ''}$cantidad',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: cantidad > 0 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Usuario: $usuario',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Motivo: $motivo',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Documento: $documento',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                  Text(
                                    'Ubicación: $ubicacion',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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