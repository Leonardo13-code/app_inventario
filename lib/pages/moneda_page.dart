import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonedaPage extends StatefulWidget {
  const MonedaPage({super.key});

  @override
  State<MonedaPage> createState() => _MonedaPageState();
}

class _MonedaPageState extends State<MonedaPage> {
  final TextEditingController montoCtrl = TextEditingController();

  double tasaBCV = 38.50;
  double tasaParalelo = 42.30;
  double tasaPersonalizada = 40.00;
  double resultado = 0.0;
  String tasaSeleccionada = 'BCV';

  @override
  void initState() {
    super.initState();
    _cargarTasas();
  }

  Future<void> _cargarTasas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tasaBCV = prefs.getDouble('tasa_bcv') ?? 38.50;
      tasaParalelo = prefs.getDouble('tasa_paralelo') ?? 42.30;
      tasaPersonalizada = prefs.getDouble('tasa_personalizada') ?? 40.00;
    });
  }

  Future<void> _guardarTasas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('tasa_bcv', tasaBCV);
    await prefs.setDouble('tasa_paralelo', tasaParalelo);
    await prefs.setDouble('tasa_personalizada', tasaPersonalizada);
  }

  void _convertir() {
    double monto = double.tryParse(montoCtrl.text) ?? 0.0;
    double tasa;

    switch (tasaSeleccionada) {
      case 'BCV':
        tasa = tasaBCV;
        break;
      case 'Paralelo':
        tasa = tasaParalelo;
        break;
      case 'Promedio':
        tasa = (tasaBCV + tasaParalelo) / 2;
        break;
      case 'Personalizada':
        tasa = tasaPersonalizada;
        break;
      default:
        tasa = tasaBCV;
    }

    setState(() {
      resultado = monto * tasa;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Conversión de Moneda")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: montoCtrl,
              decoration: const InputDecoration(labelText: 'Monto en USD'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: tasaSeleccionada,
              items: ['BCV', 'Paralelo', 'Promedio', 'Personalizada']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  tasaSeleccionada = value!;
                });
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _convertir,
              child: const Text('Convertir a Bs'),
            ),
            const SizedBox(height: 10),
            Text('Resultado: Bs ${resultado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20)),

            const Divider(height: 30),

            const Text('Editar tasas manualmente', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              decoration: const InputDecoration(labelText: 'Tasa BCV'),
              keyboardType: TextInputType.number,
              onChanged: (v) => tasaBCV = double.tryParse(v) ?? tasaBCV,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Tasa Paralelo'),
              keyboardType: TextInputType.number,
              onChanged: (v) => tasaParalelo = double.tryParse(v) ?? tasaParalelo,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Tasa Personalizada'),
              keyboardType: TextInputType.number,
              onChanged: (v) => tasaPersonalizada = double.tryParse(v) ?? tasaPersonalizada,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                _guardarTasas();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tasas guardadas")));
              },
              child: const Text("Guardar tasas manualmente"),
            ),
          ],
        ),
      ),
    );
  }
}
