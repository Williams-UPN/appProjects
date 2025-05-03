import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClienteNuevoScreen extends StatefulWidget {
  const ClienteNuevoScreen({super.key});

  @override
  State<ClienteNuevoScreen> createState() => _ClienteNuevoScreenState();
}

class _ClienteNuevoScreenState extends State<ClienteNuevoScreen> {
  final _formKeyCliente = GlobalKey<FormState>();
  final _formKeyPrestamo = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _negocioCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();

  int? _plazoDias;
  DateTime _fechaPrimerPago = DateTime.now().add(const Duration(days: 1));

  // Variables para la vista previa; NO se envían al servidor:
  int _totalPagar = 0;
  int _cuotaDiaria = 0;
  int _ultimaCuota = 0;

  bool _loading = false;
  int _currentStep = 0;

  /// Recalcula solo para mostrar al usuario (preview).
  void _recalcular() {
    final monto = int.tryParse(_montoCtrl.text) ?? 0;
    final plazo = _plazoDias ?? 0;
    if (monto > 0 && plazo > 0) {
      final tasa = plazo == 12 ? 10 : 20;
      _totalPagar = monto + (monto * tasa ~/ 100);
      _cuotaDiaria = (_totalPagar / plazo).ceil();
      _ultimaCuota = _totalPagar - _cuotaDiaria * (plazo - 1);
      // _fechaFinal ya no existe, así que omitimos esa línea
    } else {
      _totalPagar = _cuotaDiaria = _ultimaCuota = 0;
      // idem: no reasignamos _fechaFinal
    }
    setState(() {});
  }

  Future<void> _pickFechaPrimerPago() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPrimerPago,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _fechaPrimerPago = picked;
      _recalcular();
    }
  }

  bool _puedeCalcular() {
    final montoValido =
        int.tryParse(_montoCtrl.text) != null && int.parse(_montoCtrl.text) > 0;
    final plazoValido = _plazoDias != null;
    return montoValido && plazoValido;
  }

  /// Envía SOLO los campos canónicos al servidor.
  Future<void> _guardarTodo() async {
    if (!_formKeyCliente.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!_formKeyPrestamo.currentState!.validate()) {
      setState(() => _currentStep = 1);
      return;
    }

    setState(() => _loading = true);
    try {
      final supabase = Supabase.instance.client;
      final data = {
        'nombre': _nombreCtrl.text,
        'telefono': _telefonoCtrl.text,
        'direccion': _direccionCtrl.text,
        'negocio': _negocioCtrl.text,
        'monto_solicitado': int.parse(_montoCtrl.text),
        'plazo_dias': _plazoDias,
        'fecha_primer_pago': _fechaPrimerPago.toUtc().toIso8601String(),
      };
      await supabase.from('clientes').insert(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro guardado exitosamente')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _negocioCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro Cliente y Préstamo')),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF90CAF9),
                onPrimary: Colors.white,
                secondary: const Color(0xFF90CAF9),
              ),
          iconTheme: const IconThemeData(color: Color(0xFF90CAF9)),
        ),
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep < 1) {
              if (_formKeyCliente.currentState!.validate()) {
                setState(() => _currentStep++);
              }
            } else {
              _guardarTodo();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          steps: [
            Step(
              title: const Text('Datos del Cliente'),
              content: Form(
                key: _formKeyCliente,
                child: Column(children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Nombre completo'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: _telefonoCtrl,
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v!.length != 9 ? 'Debe tener 9 dígitos' : null,
                  ),
                  TextFormField(
                    controller: _direccionCtrl,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                  TextFormField(
                    controller: _negocioCtrl,
                    decoration: const InputDecoration(labelText: 'Negocio'),
                  ),
                ]),
              ),
              isActive: _currentStep == 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Términos del Préstamo'),
              content: Form(
                key: _formKeyPrestamo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _montoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Monto solicitado (S/)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          int.tryParse(v!) == null ? 'Número inválido' : null,
                      onChanged: (_) => _recalcular(),
                    ),
                    DropdownButtonFormField<int>(
                      value: _plazoDias,
                      items: const [12, 24]
                          .map((d) => DropdownMenuItem(
                              value: d, child: Text('$d días')))
                          .toList(),
                      decoration: const InputDecoration(labelText: 'Plazo'),
                      onChanged: (v) {
                        _plazoDias = v;
                        _recalcular();
                      },
                      validator: (v) => v == null ? 'Seleccione plazo' : null,
                    ),
                    if (_puedeCalcular()) ...[
                      const SizedBox(height: 16),
                      ListTile(
                        onTap: _pickFechaPrimerPago,
                        title: const Text('Fecha de primer pago'),
                        subtitle: Text(
                          '${_fechaPrimerPago.year.toString().padLeft(4, '0')}-'
                          '${_fechaPrimerPago.month.toString().padLeft(2, '0')}-'
                          '${_fechaPrimerPago.day.toString().padLeft(2, '0')}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                      ),
                      ListTile(
                        title: const Text('Total a pagar'),
                        subtitle: Text('S/ $_totalPagar'),
                      ),
                      ListTile(
                        title: const Text('Cuota diaria'),
                        subtitle: Text('S/ $_cuotaDiaria'),
                      ),
                      if (_cuotaDiaria != _ultimaCuota)
                        ListTile(
                          title: const Text('Última cuota'),
                          subtitle: Text('S/ $_ultimaCuota'),
                        ),
                    ],
                  ],
                ),
              ),
              isActive: _currentStep == 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
          ],
          controlsBuilder: (ctx, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(
                        color: Color(0xFFBBDEFB),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Atrás'),
                  ),
                const Spacer(),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBBDEFB),
                          foregroundColor: Colors.black,
                        ),
                        child:
                            Text(_currentStep == 1 ? 'Confirmar' : 'Siguiente'),
                      ),
              ]),
            );
          },
        ),
      ),
    );
  }
}
