// lib/services/tasa_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TasaService {
  // CLAVE API
  final String _apiKey = 'sk_9MHzw783n1IeZGR1YHkl7MzAqUe9s2LL'; 
  // ENDPOINT
  final String _baseUrl = 'https://bcvapi.tech/api/v1/dolar'; 
  
  // Clave para guardar el valor en SharedPreferences
  final String _shPrefKey = 'dolar_bcv'; 
  
  // Valor por defecto en caso de fallo (fallback)
  final double _fallbackRate = 236.50; 

  // --- FUNCIÓN PRINCIPAL: Obtener la tasa de la API ---
  Future<double> getDolarBCVRate() async {
    final prefs = await SharedPreferences.getInstance();
    //Verificar si la API está habilitada (por defecto es true)
    final bool apiEnabled = prefs.getBool('api_dolar_habilitada') ?? true;

    if (!apiEnabled) {
      // Si la API está deshabilitada, cargamos el valor manual guardado.
      return prefs.getDouble(_shPrefKey) ?? _fallbackRate;
    }
    
    try {
      final url = Uri.parse(_baseUrl);
      
      // 1. Configurar la cabecera (Header)
      final response = await http.get(
        url,
        headers: {
          // Usar la API Key directamente como valor de Authorization
          'Authorization': _apiKey, 
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // 2. Procesar la respuesta
        final data = json.decode(response.body);
        
        // La API devuelve el campo 'tasa'
        final double tasa = (data['tasa'] as num?)?.toDouble() ?? _fallbackRate; 
        
        // 3. Guardar la tasa obtenida en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_shPrefKey, tasa); 
        
        return tasa;
        
      } else {
        // Error de autenticación (ej: 401) o de servidor
        print('Error de API: ${response.statusCode} - ${response.body}');
        return await _getFallbackRate();
      }
      
    } catch (e) {
      // Error de conexión (ej: no hay internet)
      print('Error de conexión al obtener la tasa: $e');
      return await _getFallbackRate(); 
    }
  }
  
  // --- Función auxiliar para la tasa de respaldo ---
  Future<double> _getFallbackRate() async {
    final prefs = await SharedPreferences.getInstance();
    // Carga la última tasa guardada o el valor por defecto
    return prefs.getDouble(_shPrefKey) ?? _fallbackRate;
  }
}