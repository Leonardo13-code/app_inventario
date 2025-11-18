// lib/pages/configuracion_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; 

const Color invenPrimaryColor = Color(0xFF00508C);

class ConfiguracionPage extends StatefulWidget { 
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> { 
  bool _apiDolarEnabled = true; // Estado local

  @override
  void initState() {
    super.initState();
    _loadApiPreference();
  }

  // Carga el estado inicial del switch
  Future<void> _loadApiPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiDolarEnabled = prefs.getBool('api_dolar_habilitada') ?? true;
    });
  }

  // Maneja el cambio del switch y lo persiste
  Future<void> _toggleApiDolar(bool newValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('api_dolar_habilitada', newValue);
    setState(() {
      _apiDolarEnabled = newValue;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newValue 
          ? 'Actualización BCV automático ACTIVADO' 
          : 'Actualización BCV manual ACTIVADO')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          // =================================================================
          // === CONFIGURACIÓN: Habilitar API de Tasa ===
          // =================================================================
          SwitchListTile(
            title: const Text('Habilitar Actualización Automática BCV'),
            subtitle: Text(_apiDolarEnabled
                ? 'La tasa BCV se actualizará con el botón en Moneda.'
                : 'La tasa BCV debe ser actualizada manualmente en Moneda.'),
            value: _apiDolarEnabled,
            onChanged: _toggleApiDolar,
            secondary: const Icon(Icons.api, color: invenPrimaryColor),
          ),
          
          const Divider(height: 30),
          
          // =================================================================
          // === CONFIGURACIÓN: UMBRAL DE STOCK BAJO ===
          // =================================================================
          _buildConfigItem(
            context,
            title: 'Umbral de Stock Bajo',
            subtitle: 'Define el número de unidades para activar la alerta crítica de stock en la pantalla principal.',
            icon: Icons.notifications_active,
            onTap: () => _mostrarDialogoUmbralStock(context), 
          ),
          
          const Divider(height: 30),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Cualquier duda o sugerencia, por favor contacta al equipo de desarrollo de InVen.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // Función auxiliar para construir ítems de configuración
  Widget _buildConfigItem(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: invenPrimaryColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }

  // Función para mostrar el diálogo de umbral de stock
  Future<void> _mostrarDialogoUmbralStock(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUmbral = prefs.getInt('stock_bajo_umbral') ?? 10;
    final TextEditingController controller = TextEditingController(text: currentUmbral.toString());

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Establecer Umbral'),
        content: TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Unidades',
            hintText: 'Ej. 2',
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () async {
              final int? newUmbral = int.tryParse(controller.text);
              if (newUmbral != null && newUmbral >= 1) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('stock_bajo_umbral', newUmbral);
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Umbral guardado: $newUmbral unidades.')),
                  );
                  Navigator.of(dialogContext).pop(); 
                  // Esto cierra ConfiguracionPage si es el último en el stack
                  Navigator.of(context).pop(); 
                }
              } else {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa un número entero válido (mínimo 1).')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}