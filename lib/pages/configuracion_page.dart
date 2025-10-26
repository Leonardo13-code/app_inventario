// lib/pages/configuracion_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Importación requerida

// Definición del color primario
const Color invenPrimaryColor = Color(0xFF00508C);

class ConfiguracionPage extends StatelessWidget {
  const ConfiguracionPage({super.key});

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
          // === ÚNICA CONFIGURACIÓN: UMBRAL DE STOCK BAJO ===
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
              'Otras opciones como Tasa de Cambio, Inventario y el Historial completo se encuentran directamente en los accesos del menú principal (Drawer).',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para construir cada item de la lista de configuración
  Widget _buildConfigItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: invenPrimaryColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// --- LÓGICA DEL DIÁLOGO PARA EL UMBRAL DE STOCK BAJO ---

Future<void> _mostrarDialogoUmbralStock(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  
  // Cargar el valor actual, usando 10 como valor por defecto
  final int currentUmbral = prefs.getInt('stock_bajo_umbral') ?? 10;
  final TextEditingController controller = TextEditingController(text: currentUmbral.toString()); 
  
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Definir Umbral de Stock Bajo'),
        content: TextField(
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
            onPressed: () {
              final int? newUmbral = int.tryParse(controller.text);
              if (newUmbral != null && newUmbral >= 1) {
                // 1. GUARDADO: Guardar el nuevo umbral
                prefs.setInt('stock_bajo_umbral', newUmbral);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Umbral guardado: $newUmbral unidades.')),
                );
                // 2. Cerrar el diálogo
                Navigator.of(dialogContext).pop(); 
                // 3. Cerrar la página de Configuración (esto disparará el refresco en PantallaPrincipal)
                Navigator.of(context).pop(); 
              } else {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Por favor, ingresa un número entero válido (mínimo 1).')),
                );
              }
            },
          ),
        ],
      );
    },
  );
}