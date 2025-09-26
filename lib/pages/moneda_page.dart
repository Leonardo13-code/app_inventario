// lib/pages/moneda_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonedaPage extends StatefulWidget {
  const MonedaPage({super.key});

  @override
  State<MonedaPage> createState() => _MonedaPageState();
}

class _MonedaPageState extends State<MonedaPage> {
  final TextEditingController montoCtrl = TextEditingController();

  double dolarBCV = 0.0;
  double tasaEuro = 0.0;
  double tasaPersonalizada = 0.0;
  double resultado = 0.0;
  String tasaSeleccionada = 'Dólar BCV';

  late double _tasaConversion;

  @override
  void initState() {
    super.initState();
    _cargarTasas();
  }

  Future<void> _cargarTasas() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Carga las tasas guardadas o usa valores predeterminados
      dolarBCV = prefs.getDouble('dolar_bcv') ?? 38.50;
      tasaEuro = prefs.getDouble('tasa_euro') ?? 42.30;
      tasaPersonalizada = prefs.getDouble('tasa_personalizada') ?? 40.00;

      // Establece la tasa inicial para la conversión
      _tasaConversion = prefs.getDouble('tasa_conversion') ?? dolarBCV;
      _determinarTasaSeleccionada();
    });
  }

  Future<void> _guardarTasas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('dolar_bcv', dolarBCV);
    await prefs.setDouble('tasa_euro', tasaEuro);
    await prefs.setDouble('tasa_personalizada', tasaPersonalizada);
    await prefs.setDouble('tasa_conversion', _tasaConversion);
  }

  void _determinarTasaSeleccionada() {
    if (_tasaConversion == dolarBCV) {
      tasaSeleccionada = 'Dólar BCV';
    } else if (_tasaConversion == tasaEuro) {
      tasaSeleccionada = 'Euro';
    } else if (_tasaConversion == tasaPersonalizada) {
      tasaSeleccionada = 'Personalizada';
    } else {
      tasaSeleccionada = 'Promedio';
    }
  }

  void _convertir() {
    double monto = double.tryParse(montoCtrl.text) ?? 0.0;

    switch (tasaSeleccionada) {
      case 'Dólar BCV':
        _tasaConversion = dolarBCV;
        break;
      case 'Euro':
        _tasaConversion = tasaEuro;
        break;
      case 'Promedio':
        _tasaConversion = (dolarBCV + tasaEuro) / 2;
        break;
      case 'Personalizada':
        _tasaConversion = tasaPersonalizada;
        break;
      default:
        _tasaConversion = dolarBCV;
    }

    setState(() {
      resultado = monto * _tasaConversion;
    });

    _guardarTasas();
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
              items: ['Dólar BCV', 'Euro', 'Promedio', 'Personalizada']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  tasaSeleccionada = value!;
                });
                _convertir();
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
            TextFormField(
              decoration: InputDecoration(labelText: 'Tasa Dólar BCV (Actual: ${dolarBCV.toStringAsFixed(2)})'),
              keyboardType: TextInputType.number,
              onChanged: (v) => dolarBCV = double.tryParse(v) ?? dolarBCV,
            ),
            TextFormField(
              decoration: InputDecoration(labelText: 'Tasa Euro (Actual: ${tasaEuro.toStringAsFixed(2)})'),
              keyboardType: TextInputType.number,
              onChanged: (v) => tasaEuro = double.tryParse(v) ?? tasaEuro,
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