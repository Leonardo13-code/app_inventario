// lib/pages/configuracion_page.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:InVen/services/backup_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:InVen/services/firestore_service.dart';

const Color invenPrimaryColor = Color(0xFF00508C);

class ConfiguracionPage extends StatefulWidget { 
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> { 
  final FirestoreService _firestoreService = FirestoreService(); 
  bool _apiDolarEnabled = true; // Estado local
  String? _manualUrl;

  final String _adminEmail = "leonalexbarreto@gmail.com";

  @override
  void initState() {
    super.initState();
    _loadApiPreference();
    _loadManualUrl();
  }

  // Carga el estado inicial del switch
  Future<void> _loadApiPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiDolarEnabled = prefs.getBool('api_dolar_habilitada') ?? true;
    });
  }

  // Cargar la URL del manual desde Firestore
  Future<void> _loadManualUrl() async {
    // Llama al nuevo método del servicio para obtener el campo 'manual_url'
    final url = await _firestoreService.getGlobalConfigUrl('manual_url');
    if (mounted) {
      setState(() {
        _manualUrl = url;
      });
    }
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

  // Función de peligro: Borrado total
  Future<void> _resetAppDatabase(BuildContext context) async {
    // --- 1. Diálogo Mejorado con Opción de Respaldo ---
    final String? decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Restablecer todo el sistema?'),
        content: const Text(
            'Esta acción borrará PERMANENTEMENTE todos los datos.\n\n'
            'Se recomienda encarecidamente crear un Respaldo local antes de continuar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'CANCEL'),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.save_alt),
            onPressed: () => Navigator.pop(context, 'BACKUP'),
            label: const Text('Crear Respaldo Primero'),
          ),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, 'DELETE'),
              child: const Text('Borrar Sin Respaldo', style: TextStyle(color: Colors.white))),
        ],
      ),
    );

    if (decision == 'CANCEL' || decision == null) return;

    // --- LOGICA DE RESPALDO ---
    if (decision == 'BACKUP') {
        try {
            // Mostrar carga
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generando respaldo... Por favor espere.'))
              );
            }
            
            await BackupService().generarYDescargarRespaldo();
            
            // Preguntar de nuevo si quiere borrar ahora que ya respaldó
            if (context.mounted) {
              // Aquí podrías volver a llamar a _resetAppDatabase(context) recursivamente
              // O simplemente mostrar un diálogo de "¿Ya se descargó? ¿Procedemos a borrar?"
              // Para simplificar, asumamos que el usuario vuelve a presionar el botón rojo si quiere borrar.
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Respaldo descargado. Si deseas borrar, presiona el botón nuevamente.'), backgroundColor: Colors.green,)
              );
              return; 
            }
        } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error al crear respaldo: $e'), backgroundColor: Colors.red)
              );
            }
            return; // Abortar si falló el respaldo
        }
    }

    // 2. Segundo aviso (Validación de Credenciales - Igual que en Historial)
    // Aquí reutilizamos la lógica de seguridad.
    if (decision == 'DELETE') { 
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? password;
      final bool? segundaConfirmacion = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmación Final de Seguridad'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Para confirmar el borrado total, escribe la contraseña de: ${user.email}'),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => password = v,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (password != null && password!.isNotEmpty) {
                    Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('BORRAR TODO'),
            ),
          ],
        ),
      );

      if (segundaConfirmacion != true || password == null) return;

      // 3. Re-autenticación y Borrado
      try {
        // Validar pass
        AuthCredential credential = EmailAuthProvider.credential(email: user.email!, password: password!);
        await user.reauthenticateWithCredential(credential);

        // Mostrar indicador de carga
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => const Center(child: CircularProgressIndicator()),
          );
        }
        
        final firestore = FirebaseFirestore.instance;
        final batch = firestore.batch();

        // Listar las colecciones a borrar
        final colecciones = ['productos', 'movimientos', 'ventas'];
        
        for (var col in colecciones) {
          var snapshot = await firestore.collection(col).get();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
        }
        
        await batch.commit();
        
        // Limpiar SharedPreferences (Configuraciones locales) excepto datos de login
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); 
        // Opcional: Restaurar flags importantes si no quieres que se borre Todo (como el onboarding)
        
        if (context.mounted) {
          Navigator.pop(context); // Cerrar loader
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sistema restablecido correctamente.')));
          // Opcional: Cerrar sesión o ir al inicio
        }

      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Cerrar loader si falla
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

    Future<void> _restaurarDatos(BuildContext context) async {
      // Confirmación simple
      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Restaurar copia de seguridad?'),
          content: const Text(
              'Esto combinará los datos del archivo con los actuales. '
              'Si el archivo contiene datos que ya existen, se sobrescribirán.\n\n'
              'Asegúrate de seleccionar un archivo .json válido generado por InVen.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Seleccionar Archivo')),
          ],
        ),
      );

      if (confirmar != true) return;

      try {
        if (mounted) {
          // Mostrar Loading
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => const Center(child: CircularProgressIndicator()),
          );
        }

        await BackupService().restaurarDesdeArchivo();

        if (mounted) {
          Navigator.pop(context); // Cerrar Loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Datos restaurados exitosamente!'), backgroundColor: Colors.green),
          );
          // Opcional: Refrescar la app o navegar a inicio
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar Loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al restaurar: $e'), backgroundColor: Colors.red),
          );
        }
      }
  }

// NUEVO MÉTODO: ABRIR MANUAL
  Future<void> _abrirManualUsuario() async {
    if (_manualUrl == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La URL del manual aún no se ha cargado.')),
        );
      }
      return;
    }

    final Uri url = Uri.parse(_manualUrl!);
    
    try {
      // Abre el URL en una aplicación externa (navegador o visor de PDF)
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Abriendo Manual de Usuario en el navegador...')),
          );
        }
      } else {
        throw 'No se pudo lanzar $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir el manual: $e')),
        );
      }
    }
  }  

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    // --- LÓGICA DE COMPARACIÓN ROBUSTA ---
    // 1. Obtenemos el correo actual y lo limpiamos
    final String currentEmail = user?.email?.trim().toLowerCase() ?? '';
    // 2. Limpiamos el correo admin definido
    final String adminEmailClean = _adminEmail.trim().toLowerCase();
    
    // 3. Imprimimos en consola para verificar (Mira esto en tu terminal)
    print("Correo Actual: '$currentEmail'");
    print("Correo Admin Esperado: '$adminEmailClean'");
    print("¿Son iguales?: ${currentEmail == adminEmailClean}");

    // 4. Definimos si es admin
    final bool isAdmin = currentEmail == adminEmailClean;
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

            // ==========================================
            // --- NUEVA SECCIÓN: MANUAL DE USUARIO ---
            // ==========================================
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.indigo),
              title: const Text(
                'Manual de Usuario (PDF)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _manualUrl == null 
                  ? 'Cargando URL desde Firebase...' // Estado de carga
                  : 'Toque para descargar/abrir la guía completa de uso de InVen.',
              ),
              trailing: _manualUrl == null
                // Indicador de carga si la URL no ha cargado
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.download),
              // El botón es nulo (deshabilitado) si la URL no ha cargado
              onTap: _manualUrl == null ? null : _abrirManualUsuario, 
            ),

            const Divider(height: 30),
          
          // =================================================================
          // === CONFIGURACIÓN: UMBRAL DE STOCK BAJO ===
          // =================================================================
          if (isAdmin) ...[
          _buildConfigItem(
            context,
            title: 'Umbral de Stock Bajo',
            subtitle: 'Define el número de unidades para activar la alerta crítica de stock en la pantalla principal.',
            icon: Icons.notifications_active,
            onTap: () => _mostrarDialogoUmbralStock(context), 
          ),
          
          const Divider(height: 30),

        // =================================================================
        // === NUEVA CONFIGURACIÓN: DATOS DE LA EMPRESA ===
        // =================================================================
          _buildConfigItem(
            context,
            title: 'Datos de la Empresa (Facturación)',
            subtitle: 'Define el nombre, RIF y dirección que aparecerán en las facturas PDF.',
            icon: Icons.store,
            onTap: () => _mostrarDialogoDatosEmpresa(context), // 👈 Función que acabas de crear
          ),

          const Divider(height: 30, thickness: 1),

          // ==========================================
          // === ZONA DE PELIGRO ===
          // ==========================================
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 10.0),
            child: Text('Zona de Peligro (Solo Admin)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red, size: 30),
            title: const Text('Restablecer Sistema', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Borra todos los datos y configuraciones.'),
            onTap: () => _resetAppDatabase(context),
          ),

          const Divider(height: 30),

          // ==========================================
          // === RESPALDO Y RESTAURACIÓN DE DATOS ===
          // ==========================================

          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.blue, size: 30),
            title: const Text('Restaurar Respaldo', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Importar datos desde archivo JSON.'),
            onTap: () => _restaurarDatos(context),
          ),

          if (!isAdmin)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                    child: Text(
                        'Funciones administrativas restringidas.',
                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
                    )
                ),
              ),
          ],

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

  // Función auxiliar para mostrar el diálogo de edición de datos de la empresa
  Future<void> _mostrarDialogoDatosEmpresa(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Cargar valores actuales
    final nameController = TextEditingController(text: prefs.getString('business_name') ?? 'TU NEGOCIO DE INVENTARIO C.A.');
    final rifController = TextEditingController(text: prefs.getString('business_rif') ?? 'J-00000000-0');
    final addressController = TextEditingController(text: prefs.getString('business_address') ?? 'Dirección no especificada');

    return showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Datos de la Empresa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre de la Empresa'),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
                TextFormField(
                  controller: rifController,
                  decoration: const InputDecoration(labelText: 'RIF/NIT'),
                ),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Dirección'),
                  maxLines: 2,
                ),
              ],
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
                // 2. GUARDAR: Guardar los nuevos datos
                await prefs.setString('business_name', nameController.text.trim());
                await prefs.setString('business_rif', rifController.text.trim());
                await prefs.setString('business_address', addressController.text.trim());
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Datos de la empresa guardados con éxito.')),
                );
                
                // 3. Cerrar los diálogos y refrescar la pantalla principal
                Navigator.of(dialogContext).pop(); 
                Navigator.of(context).pop(); 
              },
            ),
          ],
        );
      },
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