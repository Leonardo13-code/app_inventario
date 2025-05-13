import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'productos_page.dart';

class PantallaPrincipal extends StatelessWidget {
  const PantallaPrincipal({super.key});

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sesión cerrada")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sistema de Inventario'),
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          _crearOpcion(context, Icons.inventory, "Productos", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProductosPage()),
            );
          }),

          _crearOpcion(context, Icons.add_shopping_cart, "Entradas", () {}),
          _crearOpcion(context, Icons.remove_shopping_cart, "Salidas", () {}),
          _crearOpcion(context, Icons.history, "Historial", () {}),
          _crearOpcion(context, Icons.attach_money, "Moneda", () {}),
          _crearOpcion(context, Icons.calculate, "Costos", () {}),
        ],
      ),
    );
  }

  Widget _crearOpcion(
    BuildContext context,
    IconData icono,
    String texto,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.teal[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 40, color: Colors.teal[700]),
              const SizedBox(height: 10),
              Text(texto, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
