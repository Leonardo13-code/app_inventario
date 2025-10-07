// lib/pages/historial_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ¡Necesario para la autenticación!
import 'package:intl/intl.dart';
import 'package:InVen/services/firestore_service.dart';

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key});

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  final FirestoreService _firestoreService = FirestoreService();
  final String _collectionName = 'movimientos';
  
  // Variables para la limpieza manual
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  // --- NUEVA FUNCIÓN: VALIDACIÓN DE CONTRASEÑA ---

  Future<bool> _validarCredenciales(BuildContext context) async {
    // 1. Obtener el usuario actual
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Si no hay usuario logueado, alertar y salir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No hay un usuario autenticado.')),
        );
      }
      return false;
    }

    String? password;
    final String userEmail = user.email!;
    
    // 2. Mostrar diálogo de solicitud de contraseña
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmación de Seguridad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Por seguridad, ingrese su contraseña para confirmar la eliminación de historial (${userEmail}):'),
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

    // 3. Intentar reautenticar (Validar)
    try {
      final credential = EmailAuthProvider.credential(email: userEmail, password: password!);
      await user.reauthenticateWithCredential(credential);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales validadas. Procediendo a eliminar.')),
        );
      }
      return true; // Éxito en la validación
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
      return false; // Falla en la validación
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
      // **CORRECCIÓN: Configuración del idioma** (Se hace a nivel de MaterialApp, pero se mantiene la sintaxis)
      // builder: (context, child) => Localizations.override(
      //   context: context,
      //   locale: const Locale('es', 'ES'),
      //   child: child,
      // ),
    );

    if (picked != null) {
      final DateTime adjustedDate = esFechaInicio
          ? picked.copyWith(hour: 0, minute: 0, second: 0, microsecond: 0, millisecond: 0)
          : picked.copyWith(hour: 23, minute: 59, second: 59, microsecond: 999, millisecond: 999);
      
      if (context.mounted) { // Usamos context.mounted ya que estamos en un async
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
              title: const Text('Limpieza de Historial'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seleccione el rango de fechas para la eliminación PERMANENTE de movimientos:'),
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

  // --- NUEVA FUNCIÓN: PROCESO SECUENCIAL ---
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
    
    final Timestamp startTimestamp = Timestamp.fromDate(_selectedStartDate!);
    final Timestamp endTimestamp = Timestamp.fromDate(_selectedEndDate!);

    // Paso 1: Contar documentos en el rango
    final countSnapshot = await FirebaseFirestore.instance
        .collection(_collectionName)
        .where('fecha', isGreaterThanOrEqualTo: startTimestamp) 
        .where('fecha', isLessThanOrEqualTo: endTimestamp)
        .count()
        .get();

    final int count = countSnapshot.count ?? 0;
    
    // Verificación de mounted después del await.
    if (!mounted) return;
    
    // Si el contador es 0, no continuamos y notificamos al usuario.
    if (count == 0) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(content: Text('No se encontraron movimientos en el rango seleccionado. Nada que eliminar.')),
        );
        setState(() {
            _selectedStartDate = null;
            _selectedEndDate = null;
        });
        return; 
    }

    // Paso 2: Mostrar diálogo de confirmación 
    final bool? confirmar = await showDialog<bool>(
      context: parentContext, 
      builder: (context) => AlertDialog(
        title: const Text('¡ADVERTENCIA! Eliminación Masiva'),
        content: Text(
          'Se eliminarán PERMANENTEMENTE $count movimientos de inventario '
          'registrados entre el ${DateFormat('dd/MM/yyyy').format(_selectedStartDate!)} y el ${DateFormat('dd/MM/yyyy').format(_selectedEndDate!)}.\n\n'
          'Esta acción NO es reversible y no afectará tu stock actual. ¿Desea continuar?',
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

    // Verificación de mounted después del segundo await.
    if (!mounted) return;

    // Paso 3: Ejecutar la eliminación por lotes
    if (confirmar == true) {
      try {
        await _batchDeleteDocuments(_collectionName, startTimestamp, endTimestamp);
        
        if (mounted) {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            SnackBar(content: Text('Se eliminaron $count movimientos correctamente.')),
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
    
    // Limpiamos las fechas seleccionadas
    if (mounted) {
        setState(() {
            _selectedStartDate = null;
            _selectedEndDate = null;
        });
    }
  }

  Future<void> _batchDeleteDocuments(String collection, Timestamp startDate, Timestamp endDate) async {
    QuerySnapshot snapshot;
    
    do {
      snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where('fecha', isGreaterThanOrEqualTo: startDate) 
          .where('fecha', isLessThanOrEqualTo: endDate)
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
  
  // --- BUILD METHOD (sin cambios relevantes) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historial de Movimientos',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services, color: Colors.white),
            tooltip: 'Limpiar Historial',
            onPressed: _mostrarDialogoLimpieza,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getCollection('movimientos', orderByField: 'fecha').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final movimientos = snapshot.data!.docs;
          
          Map<String, List<DocumentSnapshot>> groupedMovimientos = {};
          Map<String, DateTime> dateMap = {}; 
          
          for (var doc in movimientos) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final Timestamp? timestamp = data['fecha'] as Timestamp?;
            if (timestamp == null) continue;
            
            final DateTime date = timestamp.toDate();
            final String formattedDateKey = DateFormat('dd MMMM yyyy').format(date);

            if (!groupedMovimientos.containsKey(formattedDateKey)) {
              groupedMovimientos[formattedDateKey] = [];
              dateMap[formattedDateKey] = date; 
            }
            groupedMovimientos[formattedDateKey]!.add(doc); 
          }
          
          List<MapEntry<String, List<DocumentSnapshot>>> sortedGroups = groupedMovimientos.entries.toList()
            ..sort((a, b) => dateMap[b.key]!.compareTo(dateMap[a.key]!));

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
                      final double cantidad = (mov['cantidad'] as num?)?.toDouble() ?? 0.0; 
                      final double costoUnitario = (mov['costoUnitario'] as num?)?.toDouble() ?? 0.0;
                      final productoNombre = mov['productoNombre'] ?? 'Producto Desconocido';
                      final usuario = mov['usuario'] ?? 'Anónimo';
                      final ubicacion = mov['ubicacion'] ?? 'No especificada';
                      final motivo = mov['motivo'] ?? 'No especificado';
                      final fecha = (mov['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
                      
                      final isEntrada = tipo == 'Entrada';
                      final color = isEntrada ? Colors.green.shade100 : Colors.red.shade100;
                      final icon = isEntrada ? Icons.arrow_downward : Icons.arrow_upward;
                      final iconColor = isEntrada ? Colors.green.shade800 : Colors.red.shade800;
                      final String cantidadText = cantidad.abs().toStringAsFixed(cantidad.abs() == cantidad.abs().truncateToDouble() ? 0 : 2);
                      final String costoTotal = (cantidad.abs() * costoUnitario).toStringAsFixed(2);
                      
                      final String costoTotalDisplay = '\$${costoTotal}';

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
                              Text('Cantidad: $cantidadText'),
                              Text('Costo Unitario: \$${costoUnitario.toStringAsFixed(2)}'),
                              Text('Costo Total: $costoTotalDisplay'),
                              const Divider(height: 10),
                              Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fecha)}'),
                              Text('Usuario: $usuario'),
                              if (ubicacion != 'No especificada') Text('Ubicación: $ubicacion'),
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