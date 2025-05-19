// lib/screens/cliente_nuevo/cliente_nuevo_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../models/cliente.dart';
import '../../viewmodels/cliente_nuevo_viewmodel.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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

  bool _mapaEnLineaVisible = false;
  GoogleMapController? _controladorMapaEnLinea;
  static const LatLng _limaCentro = LatLng(-12.046374, -77.042793);
  CameraPosition _posicionCamaraMapaEnLinea =
      const CameraPosition(target: _limaCentro, zoom: 12.0);
  Set<Marker> _marcadoresMapaEnLinea = {};

  LatLng? _selectedLocation;
  bool _mapPermissionGranted = false;
  @override
  void initState() {
    super.initState();
    _vm = context.read<ClienteNuevoViewModel>();
    _checkLocationPermission();
    _resetForm();
    _vm.resetStep();
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
            'Permiso de ubicación denegado permanentemente. Habilítelo en la configuración.'),
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
    final Color tuColornegro = const Color.fromARGB(255, 3, 3, 3);
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
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: DialogTheme(backgroundColor: Colors.white),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: tuColornegro),
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
      _controladorMapaEnLinea?.animateCamera(
          CameraUpdate.newCameraPosition(_posicionCamaraMapaEnLinea));
    }
  }

  Future<void> _toggleYGeocodificarMapa() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (!_mapPermissionGranted) {
      await _requestLocationPermission();
      if (!mounted || !_mapPermissionGranted) {
        scaffoldMessenger.showSnackBar(const SnackBar(
            content:
                Text('Se requiere permiso de ubicación para usar el mapa.')));
        return;
      }
    }

    if (_mapaEnLineaVisible) {
      _accionCancelarMapa();
      return;
    }

    if (mounted) {
      setState(() {
        _mapaEnLineaVisible = true;
      });
    }

    LatLng targetLatLngParaMapa = _limaCentro; // Fallback muy inicial
    double zoomInicial = 12.0;
    String infoWindowTitle = 'Ubicación (arrastra para ajustar)';
    String direccionTexto = _direccionCtrl.text.trim();
    LatLng? ubicacionGpsObtenida;

    if (_mapPermissionGranted) {
      if (mounted) {
        setState(() {});
      }
      try {
        Position position = await Geolocator.getCurrentPosition(
            // ignore: deprecated_member_use
            desiredAccuracy: LocationAccuracy.medium, // Puedes ajustar esto
            // ignore: deprecated_member_use
            timeLimit: const Duration(seconds: 7) // Tiempo límite
            );
        ubicacionGpsObtenida = LatLng(position.latitude, position.longitude);
      } catch (e) {
        debugPrint("Error obteniendo ubicación GPS: $e");
        if (mounted && direccionTexto.isEmpty) {
        } else if (mounted) {}
      }
    } else {}

    if (direccionTexto.isNotEmpty) {
      if (mounted) {
        setState(() {});
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
          targetLatLngParaMapa =
              LatLng(locations.first.latitude, locations.first.longitude);
          _selectedLocation = targetLatLngParaMapa;
          infoWindowTitle = direccionTexto;
          zoomInicial = 17.0;
          await _actualizarDireccionDesdeCoordenadas(
              targetLatLngParaMapa, true);
        } else {
          if (ubicacionGpsObtenida != null) {
            targetLatLngParaMapa = ubicacionGpsObtenida;
            _selectedLocation = targetLatLngParaMapa;
            infoWindowTitle = 'Ubicación GPS aproximada';
            zoomInicial = 17.0;
            await _actualizarDireccionDesdeCoordenadas(
                targetLatLngParaMapa, true);
          } else {
            targetLatLngParaMapa = _limaCentro;
            _selectedLocation = _limaCentro;
            zoomInicial = 12.0;
            await _actualizarDireccionDesdeCoordenadas(_limaCentro, true);
          }
        }
      } catch (e) {
        debugPrint("Error geocodificando texto: $e");
        if (mounted) {}
        if (ubicacionGpsObtenida != null) {
          targetLatLngParaMapa = ubicacionGpsObtenida;
          _selectedLocation = targetLatLngParaMapa;
          infoWindowTitle = 'Ubicación GPS aproximada';
          zoomInicial = 17.0;
          await _actualizarDireccionDesdeCoordenadas(
              targetLatLngParaMapa, true);
        } else {
          targetLatLngParaMapa = _limaCentro;
          _selectedLocation = _limaCentro;
          zoomInicial = 12.0;
          await _actualizarDireccionDesdeCoordenadas(_limaCentro, true);
        }
      }
    } else {
      if (ubicacionGpsObtenida != null) {
        targetLatLngParaMapa = ubicacionGpsObtenida;
        _selectedLocation = targetLatLngParaMapa;
        infoWindowTitle = 'Ubicación GPS actual';
        zoomInicial = 17.0;
      } else {
        targetLatLngParaMapa = _limaCentro;
        _selectedLocation = _limaCentro;
        infoWindowTitle = 'Lima Centro (Ajusta la ubicación)';
        zoomInicial = 12.0;
      }
      await _actualizarDireccionDesdeCoordenadas(targetLatLngParaMapa, true);
    }

    if (mounted) {
      setState(() {
        _posicionCamaraMapaEnLinea =
            CameraPosition(target: targetLatLngParaMapa, zoom: zoomInicial);
        _marcadoresMapaEnLinea = {
          Marker(
            markerId: const MarkerId('puntoSeleccion'),
            position: targetLatLngParaMapa,
            draggable: true,
            infoWindow: InfoWindow(title: infoWindowTitle),
            onDragEnd: (newPosition) {
              _onTapMapaEnLinea(newPosition, isDrag: true);
            },
          )
        };
      });
      _controladorMapaEnLinea?.animateCamera(
          CameraUpdate.newCameraPosition(_posicionCamaraMapaEnLinea));
    }
  }

  void _onTapMapaEnLinea(LatLng tappedPoint, {bool isDrag = false}) {
    if (!mounted) return;
    _selectedLocation = tappedPoint;

    double currentZoom = _posicionCamaraMapaEnLinea.zoom;

    setState(() {
      if (!isDrag) {
        _posicionCamaraMapaEnLinea =
            CameraPosition(target: tappedPoint, zoom: currentZoom);
      } else {
        _posicionCamaraMapaEnLinea = CameraPosition(
            target: tappedPoint, zoom: _posicionCamaraMapaEnLinea.zoom);
      }
      _marcadoresMapaEnLinea = {
        Marker(
          markerId: const MarkerId('puntoSeleccion'),
          position: tappedPoint,
          draggable: true,
          onDragEnd: (newPosition) {
            _onTapMapaEnLinea(newPosition, isDrag: true);
          },
        )
      };
    });
    _actualizarDireccionDesdeCoordenadas(tappedPoint, true);
  }

  Future<void> _actualizarDireccionDesdeCoordenadas(
      LatLng point, bool actualizarCampoTextoPrincipal) async {
    if (!mounted) return;
    if (actualizarCampoTextoPrincipal) {
      setState(() {});
    }

    String addressString =
        'Lat: ${point.latitude.toStringAsFixed(5)}, Lng: ${point.longitude.toStringAsFixed(5)}';
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(point.latitude, point.longitude);
      if (!mounted) return;

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        String calle = place.thoroughfare ?? place.street ?? '';
        String numero = place.subThoroughfare ?? '';
        String nombreSubLocalidad = place.subLocality ?? '';
        String nombreLocalidad = place.locality ?? '';

        String constructedAddress = calle;
        if (numero.isNotEmpty) {
          constructedAddress +=
              (constructedAddress.isNotEmpty ? ' $numero' : numero);
        }

        if (nombreSubLocalidad.isNotEmpty) {
          if (constructedAddress.isNotEmpty &&
              !constructedAddress
                  .toLowerCase()
                  .contains(nombreSubLocalidad.toLowerCase())) {
            constructedAddress += ', $nombreSubLocalidad';
          } else if (constructedAddress.isEmpty) {
            constructedAddress += nombreSubLocalidad;
          }
        }
        if (nombreLocalidad.isNotEmpty) {
          if (constructedAddress.isNotEmpty &&
              !constructedAddress
                  .toLowerCase()
                  .contains(nombreLocalidad.toLowerCase())) {
            constructedAddress += ', $nombreLocalidad';
          } else if (constructedAddress.isEmpty) {
            constructedAddress += nombreLocalidad;
          }
        }
        addressString = constructedAddress.isNotEmpty
            ? constructedAddress
            : 'Dirección detallada no disponible.';
      } else {
        addressString =
            'No se pudo obtener dirección detallada de las coordenadas.';
      }
    } catch (e) {
      debugPrint('Error en geocodificación inversa: $e');
      addressString = 'Error al obtener dirección de coordenadas.';
    } finally {
      if (mounted) {
        setState(() {
          if (actualizarCampoTextoPrincipal) {
            _direccionCtrl.text = addressString;
          }
        });
      }
    }
  }

  void _accionAceptar() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_selectedLocation != null) {
      if (mounted) {
        setState(() {
          _mapaEnLineaVisible = false;
        });
      }
    } else {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text('No hay ubicación seleccionada en el mapa.')));
    }
  }

  void _accionCancelarMapa() {
    if (mounted) {
      setState(() {
        _mapaEnLineaVisible = false;
        _direccionCtrl.clear(); // Borra el texto del campo de dirección
        _selectedLocation = null; // Borra la ubicación seleccionada
        _marcadoresMapaEnLinea.clear(); // Limpia marcadores
        _posicionCamaraMapaEnLinea = const CameraPosition(
            target: _limaCentro, zoom: 12.0); // Resetea cámara
// Limpia feedback
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ClienteNuevoViewModel>();
    final Color actionButtonColor = const Color(0xFF90CAF9);
    final Color mapButtonIconColor = actionButtonColor;

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
          dialogTheme: DialogTheme(backgroundColor: Colors.white),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: actionButtonColor),
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
                        decoration: InputDecoration(
                          labelText: 'Dirección (Calle, Número, Referencia)',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mapaEnLineaVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.location_searching,
                              color: _mapPermissionGranted
                                  ? mapButtonIconColor
                                  : Colors.grey,
                            ),
                            tooltip: _mapaEnLineaVisible
                                ? 'Ocultar Mapa'
                                : 'Mostrar/Buscar en Mapa',
                            onPressed: _mapPermissionGranted
                                ? _toggleYGeocodificarMapa
                                : _requestLocationPermission,
                          ),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 8),
                      if (_mapaEnLineaVisible) ...[
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
                              onTap: (tappedPoint) =>
                                  _onTapMapaEnLinea(tappedPoint),
                              myLocationButtonEnabled: false,
                              myLocationEnabled: _mapPermissionGranted,
                              zoomControlsEnabled: false,
                              gestureRecognizers: <Factory<
                                  OneSequenceGestureRecognizer>>{
                                Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                                ),
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                          child: Row(
                            // Usar Row para ACEPTAR y CANCELAR en la misma línea
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('ACEPTAR'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: actionButtonColor,
                                      foregroundColor: Colors.black),
                                  onPressed: _selectedLocation != null
                                      ? _accionAceptar
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextButton(
                                  onPressed: _accionCancelarMapa,
                                  child: Text('CANCELAR',
                                      style:
                                          TextStyle(color: Colors.grey[700])),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                        items: [12, 24].map((int value) {
                          return DropdownMenuItem<int>(
                            value: value,
                            child: Text(
                              '$value días',
                              style: const TextStyle(color: Colors.black),
                            ),
                          );
                        }).toList(),
                        decoration: const InputDecoration(labelText: 'Plazo'),
                        dropdownColor: Colors.white,
                        style:
                            const TextStyle(color: Colors.black, fontSize: 16),
                        iconEnabledColor: actionButtonColor,
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
                                ? 'Confirmar'
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
