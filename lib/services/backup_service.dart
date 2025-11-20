import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart'; // Nuevo import
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class BackupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==============================================================
  // 1. GENERAR RESPALDO (MEJORADO: AHORA GUARDA LOS IDs)
  // ==============================================================
  Future<void> generarYDescargarRespaldo() async {
    try {
      final results = await Future.wait([
        _db.collection('productos').get(),
        _db.collection('ventas').get(),
        _db.collection('movimientos').get(),
      ]);

      // Helper para incluir el ID dentro del mapa de datos
      List<Map<String, dynamic>> _processDocs(QuerySnapshot snapshot) {
        return snapshot.docs.map((doc) {
          final data = _sanitizarDatos(doc.data() as Map<String, dynamic>);
          data['__doc_id__'] = doc.id; // Guardamos el ID original aquí
          return data;
        }).toList();
      }

      final Map<String, dynamic> databaseDump = {
        'metadata': {
          'fecha_respaldo': DateTime.now().toIso8601String(),
          'version_app': '1.0.0',
        },
        'productos': _processDocs(results[0]),
        'ventas': _processDocs(results[1]),
        'movimientos': _processDocs(results[2]),
      };

      final String jsonString = jsonEncode(databaseDump);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      final String fechaStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final String name = 'respaldo_inven_$fechaStr';

      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      print('Respaldo generado con éxito');
    } catch (e) {
      print('Error generando respaldo: $e');
      rethrow;
    }
  }

  // ==============================================================
  // 2. RESTAURAR RESPALDO
  // ==============================================================
  Future<void> restaurarDesdeArchivo() async {
    try {
      // A. Seleccionar archivo
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true, // Importante para Web
      );

      if (result == null) return; // Usuario canceló

      // B. Leer contenido
      String jsonContent;
      
      if (kIsWeb) {
        // En web, los bytes vienen en result.files.first.bytes
        final bytes = result.files.first.bytes;
        if (bytes == null) throw Exception('No se pudo leer el archivo web');
        jsonContent = utf8.decode(bytes);
      } else {
        // En móvil/escritorio, usamos path
        final path = result.files.single.path;
        if (path == null) throw Exception('Ruta de archivo inválida');
        final file = File(path);
        jsonContent = await file.readAsString();
      }

      // C. Decodificar JSON
      final Map<String, dynamic> data = jsonDecode(jsonContent);

      // D. Escribir en Firebase (Batch)
      final batch = _db.batch();

      // Procesar cada colección
      if (data.containsKey('productos')) _agregarAlBatch(batch, 'productos', data['productos']);
      if (data.containsKey('ventas')) _agregarAlBatch(batch, 'ventas', data['ventas']);
      if (data.containsKey('movimientos')) _agregarAlBatch(batch, 'movimientos', data['movimientos']);

      await batch.commit();
      print('Restauración completada');

    } catch (e) {
      print('Error restaurando: $e');
      rethrow;
    }
  }

  // Helper para preparar datos y agregarlos al Batch
  void _agregarAlBatch(WriteBatch batch, String collection, List<dynamic> items) {
    for (var item in items) {
      Map<String, dynamic> mapItem = item as Map<String, dynamic>;
      
      // Recuperar ID original si existe
      String? docId = mapItem['__doc_id__'];
      mapItem.remove('__doc_id__'); // Lo quitamos para no guardarlo como campo

      // Convertir Strings ISO8601 de vuelta a Timestamps de Firebase
      Map<String, dynamic> finalData = _reconstruirTimestamps(mapItem);

      final docRef = _db.collection(collection).doc(docId); // Si docId es null, genera uno nuevo (para respaldos viejos)
      batch.set(docRef, finalData); 
    }
  }

  // ==============================================================
  // HELPERS DE CONVERSIÓN DE DATOS
  // ==============================================================

  // Convierte Timestamp -> String (Para el Backup)
  Map<String, dynamic> _sanitizarDatos(Map<String, dynamic> data) {
    final Map<String, dynamic> sanitizado = Map.from(data);
    sanitizado.forEach((key, value) {
      if (value is Timestamp) {
        sanitizado[key] = value.toDate().toIso8601String();
      } else if (value is List) {
        sanitizado[key] = value.map((item) {
           if (item is Map<String, dynamic>) return _sanitizarDatos(item);
           return item;
        }).toList();
      }
    });
    return sanitizado;
  }

  // Convierte String -> Timestamp (Para la Restauración)
  Map<String, dynamic> _reconstruirTimestamps(Map<String, dynamic> data) {
    final Map<String, dynamic> reconstruido = Map.from(data);
    
    reconstruido.forEach((key, value) {
      // Detectar si es fecha por el nombre del campo o si parece fecha
      // Es más seguro guiarme por formato ISO si el campo es clave común
      bool esCampoFecha = ['fecha', 'date', 'created_at', 'timestamp'].contains(key);
      
      if (value is String && esCampoFecha) {
        try {
            reconstruido[key] = Timestamp.fromDate(DateTime.parse(value));
        } catch (_) {} // Si falla, lo deja como string
      } 
      // Caso especial: Listas dentro de mapas (ej: productos dentro de ventas)
      else if (value is List) {
        reconstruido[key] = value.map((item) {
           if (item is Map<String, dynamic>) return _reconstruirTimestamps(item);
           return item;
        }).toList();
      }
    });
    return reconstruido;
  }
}