// lib/screens/cliente_nuevo/cliente_nuevo_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import '../../viewmodels/cliente_nuevo_viewmodel.dart';

// CORRECCIÓN DEFINITIVA Y MÁS IMPORTANTE DE LA IMPORTACIÓN:
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

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
  DateTime _fechaPrimerPago = DateTime.now();
  int _totalPagar = 0, _cuotaDiaria = 0, _ultimaCuota = 0;

  late final ClienteNuevoViewModel _vm;

  // --- Variables para el Mapa en Línea ---
  bool _mapaEnLineaVisible = false;
  GoogleMapController? _controladorMapaEnLinea;
  static const LatLng _limaCentro = LatLng(-12.046374, -77.042793);
  CameraPosition _posicionCamaraMapaEnLinea =
      const CameraPosition(target: _limaCentro, zoom: 12.0);
  Set<Marker> _marcadoresMapaEnLinea = {};
  // --- Fin Variables para el Mapa en Línea ---

  LatLng? _selectedLocation; // Coordenadas finales seleccionadas
  // _selectedAddressText se usa para mostrar la dirección obtenida del mapa o mensajes de estado
  String _selectedAddressText = '';
  bool _isFetchingAddress = false;
  bool _mapPermissionGranted = false;

  get subLocalidad => null;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ClienteNuevoViewModel>();
    _checkLocationPermission();
    _resetForm();
    _vm.resetStep();
    // El listener _onDireccionChanged ya no es necesario para mostrar/ocultar el botón del mapa
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _negocioCtrl.dispose();
    _montoCtrl.dispose();
    _controladorMapaEnLinea?.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (mounted) {
      setState(() {
        _mapPermissionGranted = status.isGranted;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.request();
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _mapPermissionGranted = status.isGranted;
    });

    if (status.isPermanentlyDenied) {
      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text(
            'Permiso de ubicación denegado permanentemente. Por favor, habilítelo en la configuración de la aplicación.'),
        action:
            SnackBarAction(label: 'Abrir Config.', onPressed: openAppSettings),
      ));
    } else if (status.isDenied) {
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado.')));
    }
  }

  void _resetForm() {
    _formKeyCliente.currentState?.reset();
    _formKeyPrestamo.currentState?.reset();
    _nombreCtrl.clear();
    _telefonoCtrl.clear();
    _direccionCtrl.clear();
    _negocioCtrl.clear();
    _montoCtrl.clear();
    _plazoDias = null;
    _fechaPrimerPago = DateTime.now();
    _totalPagar = _cuotaDiaria = _ultimaCuota = 0;
    _selectedLocation = null;
    _selectedAddressText = '';
    _isFetchingAddress = false;
    _mapaEnLineaVisible = false;
    _marcadoresMapaEnLinea.clear();
    _posicionCamaraMapaEnLinea =
        const CameraPosition(target: _limaCentro, zoom: 12.0);
    if (mounted) {
      setState(() {});
    }
  }

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
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickFechaPrimerPago() async {
    final Color tuColorAzulPrincipal = const Color(0xFF90CAF9);
    final Color colorTextoSobreAzul = Colors.black;
    final Color colorTextoGeneral = Colors.black;
    final Color colorFondoDialogo = Colors.white;
    final DateTime now = DateTime.now();
    final DateTime firstSelectableDate = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaPrimerPago.isBefore(firstSelectableDate)
          ? firstSelectableDate
          : _fechaPrimerPago,
      firstDate: firstSelectableDate,
      lastDate: DateTime(2101),
      helpText: 'Seleccionar Fecha de Primer Pago',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: tuColorAzulPrincipal,
              onPrimary: colorTextoSobreAzul,
              surface: colorFondoDialogo,
              onSurface: colorTextoGeneral,
            ),
            dialogTheme: DialogTheme(backgroundColor: colorFondoDialogo),
            textButtonTheme: TextButtonThemeData(
              style:
                  TextButton.styleFrom(foregroundColor: tuColorAzulPrincipal),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _fechaPrimerPago = picked;
      });
      _recalcular();
    }
  }

  bool _puedeCalcular() {
    final m = int.tryParse(_montoCtrl.text) ?? 0;
    return m > 0 && _plazoDias != null;
  }

  void _onMapaEnLineaCreado(GoogleMapController controller) {
    if (mounted) {
      _controladorMapaEnLinea = controller;
      // Mover cámara a la posición inicial si el mapa se crea después de una búsqueda
      if (_posicionCamaraMapaEnLinea.target != _limaCentro ||
          _marcadoresMapaEnLinea.isNotEmpty) {
        _controladorMapaEnLinea?.animateCamera(
            CameraUpdate.newCameraPosition(_posicionCamaraMapaEnLinea));
      }
    }
  }

  Future<void> _gestionarMapaEnLinea() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (!_mapPermissionGranted) {
      await _requestLocationPermission();
      if (!mounted) return;
      if (!_mapPermissionGranted) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content:
                Text('Se requiere permiso de ubicación para usar el mapa.')));
        return;
      }
    }

    String direccionTexto = _direccionCtrl.text.trim();

    if (direccionTexto.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isFetchingAddress = true;
          _selectedAddressText = "Buscando dirección...";
        });
      }
      String direccionParaBuscar = direccionTexto;
      if (!direccionParaBuscar.toLowerCase().contains('lima') &&
          !direccionParaBuscar.toLowerCase().contains('perú')) {
        direccionParaBuscar += ", Lima, Perú";
      }

      try {
        List<Location> locations =
            await locationFromAddress(direccionParaBuscar);
        if (!mounted) return;

        if (locations.isNotEmpty) {
          final targetLatLng =
              LatLng(locations.first.latitude, locations.first.longitude);
          setState(() {
            _selectedLocation = targetLatLng;
            _posicionCamaraMapaEnLinea =
                CameraPosition(target: targetLatLng, zoom: 17.0);
            _marcadoresMapaEnLinea = {
              Marker(
                markerId: const MarkerId('ubicacionBuscada'),
                position: targetLatLng,
                infoWindow: InfoWindow(
                    title: _direccionCtrl.text.trim().isEmpty
                        ? "Ubicación seleccionada"
                        : _direccionCtrl.text.trim()),
                draggable: true,
                onDragEnd: (newPosition) {
                  _onTapMapaEnLinea(newPosition);
                },
              )
            };
            if (!_mapaEnLineaVisible) _mapaEnLineaVisible = true;
            _isFetchingAddress = false;
            _selectedAddressText = 'Ajusta el marcador si es necesario.';
          });
          _controladorMapaEnLinea?.animateCamera(
              CameraUpdate.newCameraPosition(_posicionCamaraMapaEnLinea));
        } else {
          if (mounted) {
            setState(() {
              _isFetchingAddress = false;
              _selectedAddressText = 'Dirección no encontrada.';
            });
          }
          scaffoldMessenger.showSnackBar(const SnackBar(
              content: Text(
                  'Dirección no encontrada. Ajusta el marcador manualmente.')));
          if (!_mapaEnLineaVisible) {
            if (mounted) {
              setState(() {
                _posicionCamaraMapaEnLinea =
                    const CameraPosition(target: _limaCentro, zoom: 12.0);
                _marcadoresMapaEnLinea = {
                  //Añadir un marcador por defecto en Lima si no se encuentra y se va a mostrar
                  Marker(
                    markerId: const MarkerId('centroLima'),
                    position: _limaCentro,
                    infoWindow: const InfoWindow(
                        title: 'Lima Centro (Ajusta la ubicación)'),
                    draggable: true,
                    onDragEnd: (newPosition) {
                      _onTapMapaEnLinea(newPosition);
                    },
                  )
                };
                _selectedLocation =
                    _limaCentro; // Establecer Lima como seleccionada por defecto
                _mapaEnLineaVisible = true;
              });
            }
            _controladorMapaEnLinea?.animateCamera(
                CameraUpdate.newCameraPosition(_posicionCamaraMapaEnLinea));
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isFetchingAddress = false;
            _selectedAddressText = 'Error al buscar dirección.';
          });
          scaffoldMessenger.showSnackBar(SnackBar(
              content: Text('Error al buscar dirección: ${e.toString()}')));
        }
      }
    } else {
      setState(() {
        if (!_mapaEnLineaVisible) {
          _posicionCamaraMapaEnLinea =
              const CameraPosition(target: _limaCentro, zoom: 12.0);
          _marcadoresMapaEnLinea = {
            Marker(
              markerId: const MarkerId('centroLimaInicial'),
              position: _limaCentro,
              infoWindow:
                  const InfoWindow(title: 'Lima Centro (Ajusta la ubicación)'),
              draggable: true,
              onDragEnd: (newPosition) {
                _onTapMapaEnLinea(newPosition);
              },
            )
          };
          _selectedLocation = _limaCentro;
          _selectedAddressText =
              'Mapa mostrado. Toca para seleccionar o arrastra el marcador.';
        }
        _mapaEnLineaVisible = !_mapaEnLineaVisible;
      });
      if (_mapaEnLineaVisible && _controladorMapaEnLinea != null) {
        _controladorMapaEnLinea!.animateCamera(
            CameraUpdate.newCameraPosition(_posicionCamaraMapaEnLinea));
      }
    }
  }

  void _onTapMapaEnLinea(LatLng tappedPoint) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = tappedPoint;
      _marcadoresMapaEnLinea = {
        Marker(
          markerId: const MarkerId('ubicacionSeleccionada'),
          position: tappedPoint,
          draggable: true,
          onDragEnd: (newPosition) {
            _onTapMapaEnLinea(newPosition);
          },
        )
      };
      _isFetchingAddress = true;
      _selectedAddressText = 'Obteniendo dirección para el punto...';
    });
    _actualizarDireccionDesdeCoordenadas(tappedPoint);
  }

  Future<void> _actualizarDireccionDesdeCoordenadas(LatLng point) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String addressString =
        'Lat: ${point.latitude.toStringAsFixed(5)}, Lng: ${point.longitude.toStringAsFixed(5)}'; // Fallback

    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        String calle = place.thoroughfare ?? place.street ?? '';
        String numero = place.subThoroughfare ?? '';
        // Estas variables locales son las que se usan para construir la dirección
        String subLocality = place.subLocality ?? ''; // Distrito o barrio
        String locality = place.locality ?? ''; // Ciudad

        String constructedAddress = calle;
        if (numero.isNotEmpty) {
          constructedAddress +=
              (constructedAddress.isNotEmpty ? ' $numero' : numero);
        }
        if (subLocality.isNotEmpty) {
          if (constructedAddress.isNotEmpty &&
              !constructedAddress
                  .toLowerCase()
                  .contains(subLocality.toLowerCase())) {
            constructedAddress += ', $subLocalidad';
          } else if (constructedAddress.isEmpty) {
            constructedAddress += subLocalidad;
          }
        }
        if (locality.isNotEmpty) {
          // Uso de la variable local 'locality'
          if (constructedAddress.isNotEmpty &&
              !constructedAddress
                  .toLowerCase()
                  .contains(locality.toLowerCase())) {
            constructedAddress += ', $locality';
          } else if (constructedAddress.isEmpty) {
            constructedAddress += locality;
          }
        }
        addressString = constructedAddress.isNotEmpty
            ? constructedAddress
            : 'Dirección no disponible desde coordenadas.';
      } else {
        addressString = 'No se pudo obtener la dirección para las coordenadas.';
      }
    } catch (e) {
      debugPrint('Error en geocodificación inversa: $e');
      addressString = 'Error al obtener dirección desde coordenadas.';
      if (mounted) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content: Text('Error al obtener la dirección desde el mapa.')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _direccionCtrl.text = addressString;
          _selectedAddressText =
              addressString; // Actualizar el mensaje/texto de estado
          _isFetchingAddress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClienteNuevoViewModel>();
    final Color actionButtonColor = const Color(0xFF90CAF9);
    final Color mapButtonBorderColor = const Color(0xFF90CAF9);
    final Color mapButtonIconColor = const Color(0xFF90CAF9);
    final Color mapButtonTextColor = Colors.black;

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
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: actionButtonColor,
                secondary: actionButtonColor,
                error: Colors.red[700],
              ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stepper(
            currentStep: vm.currentStep,
            onStepContinue: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              bool isClienteFormValid = false;
              bool isPrestamoFormValid = false;

              if (vm.currentStep == 0) {
                isClienteFormValid =
                    _formKeyCliente.currentState?.validate() ?? false;
                if (isClienteFormValid) {
                  vm.avanzarStep();
                }
              } else if (vm.currentStep == 1) {
                isPrestamoFormValid =
                    _formKeyPrestamo.currentState?.validate() ?? false;
                if (isPrestamoFormValid) {
                  final cliente = Cliente(
                    nombre: _nombreCtrl.text.trim(),
                    telefono: _telefonoCtrl.text.trim(),
                    direccion: _direccionCtrl.text.trim(),
                    negocio: _negocioCtrl.text.trim(),
                    montoSolicitado: int.tryParse(_montoCtrl.text.trim()) ?? 0,
                    plazoDias: _plazoDias ?? 0,
                    fechaPrimerPago: _fechaPrimerPago,
                    latitud: _selectedLocation?.latitude,
                    longitud: _selectedLocation?.longitude,
                  );
                  final ok = await vm.guardarCliente(cliente);
                  if (!mounted) return;
                  if (ok) {
                    scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Guardado exitoso')));
                    navigator.pop();
                  } else {
                    scaffoldMessenger.showSnackBar(
                        const SnackBar(content: Text('Error al guardar')));
                  }
                }
              }
            },
            onStepCancel: vm.retrocederStep,
            steps: [
              Step(
                title: const Text('Datos del Cliente'),
                isActive: vm.currentStep >= 0,
                state:
                    vm.currentStep > 0 ? StepState.complete : StepState.indexed,
                content: Form(
                  key: _formKeyCliente,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Nombre completo'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                      TextFormField(
                          controller: _telefonoCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Teléfono'),
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Requerido';
                            }
                            if (v.trim().length != 9) {
                              return 'Debe tener 9 dígitos';
                            }
                            return null;
                          }),
                      TextFormField(
                        controller: _direccionCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Dirección (Calle, Número, Referencia)'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ElevatedButton.icon(
                          icon: Icon(
                            _mapaEnLineaVisible
                                ? Icons.map_outlined
                                : Icons.location_searching,
                            color: _mapPermissionGranted
                                ? mapButtonIconColor
                                : Colors.orange.shade800,
                          ),
                          label: Text(
                            _mapaEnLineaVisible
                                ? 'Ocultar Mapa / Actualizar desde Dirección'
                                : 'Mostrar/Buscar Mapa con Dirección',
                            style: TextStyle(
                              color: _mapPermissionGranted
                                  ? mapButtonTextColor
                                  : Colors.orange.shade800,
                            ),
                          ),
                          onPressed: _gestionarMapaEnLinea,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mapPermissionGranted
                                ? Colors.white
                                : Colors.orange.shade100,
                            foregroundColor: _mapPermissionGranted
                                ? mapButtonBorderColor
                                : Colors.orange.shade700,
                            side: _mapPermissionGranted
                                ? BorderSide(
                                    color: mapButtonBorderColor, width: 1.5)
                                : null,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            elevation: _mapPermissionGranted ? 1 : 2,
                          ),
                        ),
                      ),
                      if (_isFetchingAddress)
                        Padding(
                          padding: const EdgeInsets.only(top: 0.0, bottom: 8.0),
                          child: Row(
                            children: [
                              const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              const SizedBox(width: 8),
                              Text(_selectedAddressText.isNotEmpty
                                  ? _selectedAddressText
                                  : "Buscando/Actualizando dirección..."),
                            ],
                          ),
                        ),
                      if (_mapaEnLineaVisible)
                        Container(
                          height: 250,
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7.0),
                            child: GoogleMap(
                              initialCameraPosition: _posicionCamaraMapaEnLinea,
                              markers: _marcadoresMapaEnLinea,
                              onMapCreated: _onMapaEnLineaCreado,
                              onTap: _onTapMapaEnLinea,
                              myLocationButtonEnabled: true,
                              myLocationEnabled: _mapPermissionGranted,
                              zoomControlsEnabled: true,
                              gestureRecognizers: const {},
                            ),
                          ),
                        ),
                      if (_selectedLocation != null &&
                          !_isFetchingAddress &&
                          !_mapaEnLineaVisible)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
                          child: Text(
                            'Ubicación seleccionada: Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                            style: TextStyle(
                                color: Colors.green.shade800, fontSize: 12),
                          ),
                        ),
                      TextFormField(
                        controller: _negocioCtrl,
                        decoration: const InputDecoration(labelText: 'Negocio'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                  ),
                ),
              ),
              Step(
                title: const Text('Términos del Préstamo'),
                isActive: vm.currentStep >= 1,
                state:
                    vm.currentStep > 1 ? StepState.complete : StepState.indexed,
                content: Form(
                  key: _formKeyPrestamo,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _montoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Monto solicitado (S/)',
                            prefixText: 'S/ '),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          final montoNum = int.tryParse(v.trim());
                          if (montoNum == null) return 'Número inválido';
                          if (montoNum <= 0) return 'Debe ser mayor a 0';
                          return null;
                        },
                        onChanged: (_) => _recalcular(),
                      ),
                      DropdownButtonFormField<int>(
                        value: _plazoDias,
                        items: const [
                          DropdownMenuItem(value: 12, child: Text('12 días')),
                          DropdownMenuItem(value: 24, child: Text('24 días')),
                        ],
                        decoration: const InputDecoration(labelText: 'Plazo'),
                        onChanged: (v) {
                          if (mounted) {
                            setState(() {
                              _plazoDias = v;
                            });
                          }
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
                            subtitle: Text('S/ $_totalPagar')),
                        ListTile(
                            title: const Text('Cuota diaria'),
                            subtitle: Text('S/ $_cuotaDiaria')),
                        if (_cuotaDiaria != _ultimaCuota)
                          ListTile(
                              title: const Text('Última cuota'),
                              subtitle: Text('S/ $_ultimaCuota')),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            controlsBuilder: (ctx, details) {
              final Color stepperButtonColor = const Color(0xFF90CAF9);
              final Color stepperButtonTextColor = Colors.black;

              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    if (details.onStepCancel != null && vm.currentStep > 0)
                      TextButton(
                        onPressed: details.onStepCancel,
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.black54),
                        child: const Text('Atrás'),
                      ),
                    const Spacer(),
                    vm.isLoading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: stepperButtonColor,
                              foregroundColor: stepperButtonTextColor,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 24),
                              shape: const StadiumBorder(),
                            ),
                            child: Text(vm.currentStep == 1
                                ? 'Confirmar y Guardar'
                                : 'Siguiente'),
                          ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
