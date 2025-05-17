import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialPage extends StatelessWidget {
  const HistorialPage({super.key});

  @override
  Widget build(BuildContext context) {
    final movimientosRef = FirebaseFirestore.instance
        .collection('movimientos')
        .orderBy('fecha', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Movimientos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: movimientosRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Error cargando historial'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final movimientos = snapshot.data!.docs;

          if (movimientos.isEmpty) return const Center(child: Text('No hay movimientos'));

          return ListView.builder(
            itemCount: movimientos.length,
            itemBuilder: (context, index) {
              final mov = movimientos[index].data() as Map<String, dynamic>;
              final productoId = mov['productoId'];
              final cantidad = mov['cantidad'];
              final fecha = (mov['fecha'] as Timestamp).toDate();
              final tipo = cantidad > 0 ? 'Entrada' : 'Salida';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('productos').doc(productoId).get(),
                builder: (context, snapshotProducto) {
                  if (!snapshotProducto.hasData) {
                    return const ListTile(title: Text("Cargando producto..."));
                  }

                  final nombreProducto = snapshotProducto.data!.get('nombre');

                  return ListTile(
                    leading: Icon(
                      cantidad > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                      color: cantidad > 0 ? Colors.green : Colors.red,
                    ),
                    title: Text(nombreProducto),
                    subtitle: Text('$tipo | ${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}'),
                    trailing: Text(
                      '${cantidad > 0 ? '+' : ''}$cantidad',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cantidad > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
