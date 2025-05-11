// lib/screens/cliente_nuevo/cliente_nuevo_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import '../../viewmodels/cliente_nuevo_viewmodel.dart';

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

  int _totalPagar = 0, _cuotaDiaria = 0, _ultimaCuota = 0;

  void _recalcular() {
    final monto = int.tryParse(_montoCtrl.text) ?? 0;
    final plazo = _plazoDias ?? 0;
    if (monto > 0 && plazo > 0) {
      final tasa = plazo == 12 ? 10 : 20;
      _totalPagar = monto + (monto * tasa ~/ 100);
      _cuotaDiaria = (_totalPagar / plazo).ceil();
      _ultimaCuota = _totalPagar - _cuotaDiaria * (plazo - 1);
    } else {
      _totalPagar = _cuotaDiaria = _ultimaCuota = 0;
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
    final m = int.tryParse(_montoCtrl.text) ?? 0;
    return m > 0 && _plazoDias != null;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClienteNuevoViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro Cliente y Préstamo'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.1),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          // Aquí mantenemos tu colorScheme y tu iconTheme:
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF90CAF9),
                secondary: const Color(0xFF90CAF9),
              ),
          iconTheme: const IconThemeData(color: Color(0xFF90CAF9)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stepper(
            currentStep: vm.currentStep,
            onStepContinue: () async {
              if (vm.currentStep == 0) {
                if (_formKeyCliente.currentState!.validate()) {
                  vm.avanzarStep();
                }
              } else {
                final cliente = Cliente(
                  nombre: _nombreCtrl.text,
                  telefono: _telefonoCtrl.text,
                  direccion: _direccionCtrl.text,
                  negocio: _negocioCtrl.text,
                  montoSolicitado: int.parse(_montoCtrl.text),
                  plazoDias: _plazoDias!,
                  fechaPrimerPago: _fechaPrimerPago,
                );
                final ok = await vm.guardarCliente(cliente);
                if (!context.mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guardado exitoso')),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al guardar')),
                  );
                }
              }
            },
            onStepCancel: vm.retrocederStep,
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
                isActive: vm.currentStep == 0,
                state:
                    vm.currentStep > 0 ? StepState.complete : StepState.indexed,
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
                                  value: d,
                                  child: Text('$d días'),
                                ))
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
                            '${_fechaPrimerPago.year.toString().padLeft(4, '0')}'
                            '-${_fechaPrimerPago.month.toString().padLeft(2, '0')}'
                            '-${_fechaPrimerPago.day.toString().padLeft(2, '0')}',
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
                isActive: vm.currentStep == 1,
                state:
                    vm.currentStep > 1 ? StepState.complete : StepState.indexed,
              ),
            ],
            controlsBuilder: (ctx, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(children: [
                  if (vm.currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      style:
                          TextButton.styleFrom(foregroundColor: Colors.black),
                      child: const Text('Atrás'),
                    ),
                  const Spacer(),
                  vm.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () {
                            debugPrint(
                                '🔔 [UI] onStepContinue pulsado en step ${vm.currentStep}');
                            details.onStepContinue?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF90CAF9),
                            foregroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                              vm.currentStep == 1 ? 'Confirmar' : 'Siguiente'),
                        ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}
