// lib/pages/moneda_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:InVen/services/tasa_service.dart'; 

class MonedaPage extends StatefulWidget {
  const MonedaPage({super.key});

  @override
  State<MonedaPage> createState() => _MonedaPageState();
}

class _MonedaPageState extends State<MonedaPage> {
  final TextEditingController montoCtrl = TextEditingController();
  final TasaService _tasaService = TasaService();

  double dolarBCV = 0.0;
  double tasaEuro = 0.0;
  double tasaPersonalizada = 0.0;
  double resultado = 0.0;
  String tasaSeleccionada = 'Dólar BCV';
  
  bool _isApiEnabledForUI = false; 
  bool _isLoadingApi = false;

  late double _tasaConversion;

  @override
  void initState() {
    super.initState();
    _cargarTasas();
    montoCtrl.addListener(_calcularConversion);
  }
  
  // --- FUNCIÓN DE CARGA ---
  Future<void> _cargarTasas() async {
    final prefs = await SharedPreferences.getInstance();
      
    setState(() {
      // 1. Cargar el estado del interruptor para la UI
      _isApiEnabledForUI = prefs.getBool('api_dolar_habilitada') ?? true;
      
      // 2. Cargar tasas guardadas (dolar_bcv será la última API o el valor manual guardado)
      dolarBCV = prefs.getDouble('dolar_bcv') ?? 236.50;
      tasaEuro = prefs.getDouble('tasa_euro') ?? 273.30;
      tasaPersonalizada = prefs.getDouble('tasa_personalizada') ?? 255.00;

      // 3. Cargar la tasa de conversión seleccionada globalmente
      _tasaConversion = prefs.getDouble('tasa_conversion') ?? dolarBCV; 
      
      // 4. Determina cuál es la tasa de conversión actual para reflejar en el Dropdown
      if (_tasaConversion == dolarBCV) {
        tasaSeleccionada = 'Dólar BCV';
      } else if (_tasaConversion == tasaEuro) {
        tasaSeleccionada = 'Euro';
      } else if (_tasaConversion == tasaPersonalizada) {
        tasaSeleccionada = 'Personalizada';
      } else {
        tasaSeleccionada = 'Dólar BCV';
        _tasaConversion = dolarBCV;
      }
    });

    _calcularConversion();
  }

  // --- FUNCIÓN DE GUARDADO ---
  // Guarda las tres tasas individuales y la tasa de conversión global seleccionada.
  Future<void> _guardarTasas() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setDouble('dolar_bcv', dolarBCV);
    await prefs.setDouble('tasa_euro', tasaEuro);
    await prefs.setDouble('tasa_personalizada', tasaPersonalizada);
    
    // GUARDA EL VALOR SELECCIONADO PARA QUE SE REFLEJE EN EL RESTO DE LA APP
    await prefs.setDouble('tasa_conversion', _tasaConversion);

    await prefs.setBool('api_dolar_habilitada', _isApiEnabledForUI);
  }

  // --- Actualizar Tasa (Botón) ---
  Future<void> _handleTasaUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final bool apiEnabled = prefs.getBool('api_dolar_habilitada') ?? true;

    if (!apiEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La actualización automática está desactivada. Actívala en Configuración para usar este botón.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    // Si la API está habilitada:
    setState(() {
      _isLoadingApi = true;
    });

    final newRate = await _tasaService.getDolarBCVRate();
    
    if (mounted) {
      setState(() {
        _isLoadingApi = false;
        dolarBCV = newRate;
        
        // Si la tasa BCV era la seleccionada, actualizamos la tasa de conversión global
        if (tasaSeleccionada == 'Dólar BCV') {
          _tasaConversion = dolarBCV;
          _guardarTasas();
        } else {
          // Si no era la BCV, solo guardamos el nuevo BCV para persistencia
          prefs.setDouble('dolar_bcv', dolarBCV);
        }
      });
      _calcularConversion();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tasa BCV actualizada: Bs ${newRate.toStringAsFixed(2)}')),
      );
    }
  }

  // --- FUNCIÓN DE CONVERSIÓN ---
  void _calcularConversion() {
    final double monto = double.tryParse(montoCtrl.text) ?? 0.0;
    setState(() {
      resultado = monto * _tasaConversion;
    });
  }

  @override
  void dispose() {
    montoCtrl.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {

    String _currentGlobalRate = _tasaConversion.toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversión de Moneda (Tasa de Cambio)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // === Sección de Actualización de Tasa Automática ===
            const Text('Actualización de Tasa BCV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Botón de Actualizar Tasa BCV
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Si está cargando o la API está deshabilitada, se deshabilita el botón
                onPressed: _isLoadingApi || !_isApiEnabledForUI ? null : _handleTasaUpdate, 
                icon: _isLoadingApi
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: Colors.white),
                label: Text(
                  _isLoadingApi 
                      ? 'Actualizando...' 
                      : _isApiEnabledForUI ? 'Actualizar Tasa BCV' : 'API Desactivada', // Texto condicional
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isApiEnabledForUI ? Colors.blue.shade700 : Colors.grey, 
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // === Sección de Conversión Rápida ===
            const Text('Convertir Dólar a Bolívar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // Dropdown para seleccionar la Tasa
            DropdownButtonFormField<String>(
              initialValue: tasaSeleccionada, 
              decoration: const InputDecoration(
                labelText: 'Seleccionar Tasa de Conversión',
                border: OutlineInputBorder(),
              ),
              items: ['Dólar BCV', 'Euro', 'Personalizada'].map((String value) {
                String displayValue;
                if (value == 'Dólar BCV') {
                  displayValue = 'Dólar BCV (Bs ${dolarBCV.toStringAsFixed(2)})';
                } 
                else if (value == 'Euro') {
                  displayValue = 'Euro (Bs ${tasaEuro.toStringAsFixed(2)})';
                }
                else {
                  displayValue = 'Personalizada (Bs ${tasaPersonalizada.toStringAsFixed(2)})';
                }
                
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(displayValue),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    tasaSeleccionada = newValue;
                    if (newValue == 'Dólar BCV') {
                      _tasaConversion = dolarBCV;
                    } else if (newValue == 'Euro') {
                      _tasaConversion = tasaEuro;
                    } else if (newValue == 'Personalizada') {
                      _tasaConversion = tasaPersonalizada;
                    }
                    _guardarTasas();
                  });
                  _calcularConversion();
                }
              },
            ),

            const SizedBox(height: 15),

            // Campo de monto en dólares
            TextFormField(
              controller: montoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto en \$',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.attach_money),
              ),
            ),
            
            const SizedBox(height: 10),
            Text(
              'Resultado: Bs ${resultado.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
            ),

            const Divider(height: 30),

            // === Sección de Edición Manual ===
            const Text('Editar tasas manualmente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Campo para Dólar BCV - Deshabilitado si la API está activa
            TextFormField(
              // Condicional: Solo se puede editar si la API está deshabilitada.
              enabled: !_isApiEnabledForUI, 
              initialValue: dolarBCV.toStringAsFixed(2), 
              decoration: InputDecoration(
                labelText: 'Tasa Dólar BCV (Actual: ${dolarBCV.toStringAsFixed(2)})',
                hintText: _isApiEnabledForUI ? 'Deshabilitado: API Activa' : 'Actualizar manualmente',
                filled: _isApiEnabledForUI,
                fillColor: _isApiEnabledForUI ? Colors.grey.shade200 : null,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final newRate = double.tryParse(v);
                if (newRate != null && newRate > 0) {
                  setState(() {
                    dolarBCV = newRate;
                    if (tasaSeleccionada == 'Dólar BCV') {
                      _tasaConversion = dolarBCV;
                    }
                  });
                  //Solo se actualiza la variable de estado. Se guardará con el botón.
                  _calcularConversion();
                }
              },
            ),
            
            const SizedBox(height: 10),

            // Campo para Euro (Siempre manual)
            TextFormField(
              initialValue: tasaEuro.toStringAsFixed(2),
              decoration: InputDecoration(
                labelText: 'Tasa Euro (Actual: ${tasaEuro.toStringAsFixed(2)})',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                 final newRate = double.tryParse(v);
                 if (newRate != null && newRate > 0) {
                    setState(() {
                        tasaEuro = newRate;
                        if (tasaSeleccionada == 'Euro') {
                            _tasaConversion = tasaEuro;
                        }
                    });
                    _calcularConversion();
                 }
              },
            ),
            
            const SizedBox(height: 10),

            // Campo para Tasa Personalizada (Siempre manual)
            TextFormField(
              initialValue: tasaPersonalizada.toStringAsFixed(2),
              decoration: const InputDecoration(
                labelText: 'Tasa Personalizada',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final newRate = double.tryParse(v);
                 if (newRate != null && newRate > 0) {
                    setState(() { 
                        tasaPersonalizada = newRate;
                        if (tasaSeleccionada == 'Personalizada') {
                            _tasaConversion = tasaPersonalizada;
                        }
                    });
                    _calcularConversion();
                 }
              },
            ),
            
            const SizedBox(height: 20),
            
            // Botón de guardado manual para todas las tasas
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _guardarTasas();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tasas guardadas (BCV, Euro, Personalizada)")));
                  _calcularConversion(); 
                },
                child: const Text("Guardar todas las tasas manualmente"),
              ),
            ),
            
            const SizedBox(height: 20),
            Text(
            'La tasa de conversión global utilizada en la app (Venta, Productos, etc.) es la actualmente seleccionada: Bs $_currentGlobalRate',
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            )
          ],
        ),
      ),
    );

  }
}