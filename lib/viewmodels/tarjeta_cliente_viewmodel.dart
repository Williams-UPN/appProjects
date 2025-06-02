// lib/viewmodels/tarjeta_cliente_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cliente_detail_read.dart';
import '../models/pago_read.dart';
import '../models/cronograma_read.dart';
import '../models/historial_read.dart';
import '../repositories/cliente_repository.dart';
import '../services/location_service.dart';

class TarjetaClienteViewModel extends ChangeNotifier {
  final ClienteRepository _repo;
  final LocationService _locationService = LocationService();
  final SupabaseClient _supabase = Supabase.instance.client;

  TarjetaClienteViewModel(this._repo);

  bool _isLoading = false;
  ClienteDetailRead? _cliente;
  List<PagoRead> _pagos = [];
  List<CronogramaRead> _cronograma = [];
  List<HistorialRead> _historiales = [];
  int? _cuotaSeleccionada;

  double _montoAdicional = 0.0;
  int _plazoRefinanciar = 0;
  double _nuevoMontoPrestado = 0.0;
  double _nuevoSaldoPendiente = 0.0;
  double _nuevaCuotaDiaria = 0.0;
  double _nuevaUltimaCuota = 0.0;
  double _nuevoMontoSolicitado = 0.0;
  int _nuevoPlazo = 12;
  DateTime? _nuevaFechaPrimerPago;

  // Getters básicos
  bool get isLoading => _isLoading;
  ClienteDetailRead? get cliente => _cliente;
  List<PagoRead> get pagos => List.unmodifiable(_pagos);
  List<CronogramaRead> get cronograma => List.unmodifiable(_cronograma);
  List<HistorialRead> get historiales => List.unmodifiable(_historiales);
  int? get cuotaSeleccionada => _cuotaSeleccionada;

// Getters para refinanciamiento (insertar justo después de los getters básicos):
  double get montoAdicional => _montoAdicional;
  int get plazoRefinanciar => _plazoRefinanciar;
  bool get puedeRefinanciar =>
      _montoAdicional > 0 && !_isLoading && _cliente != null;
  double get nuevoMontoPrestadoDisplay => _nuevoMontoPrestado;
  double get nuevoSaldoPendienteDisplay => _nuevoSaldoPendiente;
  double get nuevaCuotaDiariaDisplay => _nuevaCuotaDiaria;

  // ─────────────────────────────────────────────────────
// Getters para Nuevo Crédito
  int get nuevoPlazo => _nuevoPlazo;
  DateTime? get nuevaFechaPrimerPago => _nuevaFechaPrimerPago;
  double get nuevoMontoSolicitado => _nuevoMontoSolicitado;
  double get nuevoTotalPagar =>
      _nuevoMontoSolicitado * (1 + (_nuevoPlazo == 12 ? 0.10 : 0.20));
  double get nuevaCuotaDiaria => (nuevoTotalPagar / _nuevoPlazo).ceilToDouble();
  double get nuevaUltimaCuota =>
      nuevoTotalPagar - nuevaCuotaDiaria * (_nuevoPlazo - 1);
// ─────────────────────────────────────────────────────

  /// 1) Estado de crédito completo
  bool get isCreditComplete => _cliente?.estadoReal == 'completo';

  bool get puedeIniciarRefinanciamiento =>
      !isCreditComplete && _cliente != null;

  double get nuevaUltimaCuotaDisplay => _nuevaUltimaCuota;

  bool get puedeIniciarNuevoCredito => isCreditComplete && _cliente != null;

  /// 2) Calcula cuál es la cuota “de hoy” (la siguiente no pagada).
  int get cuotaHoy {
    final pagadas = pagos.map((p) => p.numeroCuota);
    final maxPagada =
        pagadas.isEmpty ? 0 : pagadas.reduce((a, b) => a > b ? a : b);
    return maxPagada + 1;
  }

  /// 3) Permite registrar pago si existe cuotaSeleccionada y no está ya pagada.
  bool get canRegistrarHoy {
    if (isCreditComplete || cuotaSeleccionada == null) return false;
    // extraemos números ya pagados:
    final pagadas = pagos.map((p) => p.numeroCuota);
    // sólo habilita si la cuotaSeleccionada NO está en esa lista:
    return !pagadas.contains(cuotaSeleccionada);
  }

  /// 4) Montos formateados para la UI (si el crédito está completo, siempre 0)
  double get montoPrestadoDisplay =>
      isCreditComplete ? 0.0 : (_cliente?.montoSolicitado.toDouble() ?? 0.0);

  double get saldoPendienteDisplay =>
      isCreditComplete ? 0.0 : (_cliente?.saldoPendiente.toDouble() ?? 0.0);

  double get cuotaDiariaDisplay {
    if (isCreditComplete) return 0.0;
    final numero = _cuotaSeleccionada ?? cuotaHoy;
    final data = _cronograma.firstWhere(
      (c) => c.numeroCuota == numero,
      orElse: () => CronogramaRead(
        numeroCuota: numero,
        montoCuota: _cliente?.cuotaDiaria.toDouble() ?? 0.0,
        fechaPagado: null,
      ),
    );
    return data.montoCuota.toDouble();
  }

  /// 5) Mostrar/ocultar grid
  bool get showCuotasGrid => !isCreditComplete;

  /// 6) Etiqueta del botón inferior
  String get botonLabel =>
      isCreditComplete ? 'Nuevo crédito' : 'Registrar pago';

  /// 7) Acción del botón inferior: solo activa cuando canRegistrarHoy==true
  VoidCallback? get botonAction =>
      canRegistrarHoy ? () => registrarPago() : null;

  /// 8) Texto y color de estado para la UI
  String get estadoLabel {
    if (_cliente == null) return '-';
    switch (_cliente!.estadoReal) {
      case 'proximo':
        return 'Pago próximo';
      case 'completo':
        return 'Completado';
      case 'atrasado':
        return '${_cliente!.diasReales} día(s) de atraso';
      case 'pendiente':
        return 'Pago pendiente hoy';
      default:
        return 'Al día';
    }
  }

  Color get estadoColor {
    if (_cliente == null) return Colors.grey;
    switch (_cliente!.estadoReal) {
      case 'proximo':
        return Colors.blue;
      case 'pendiente':
        return Colors.orange;
      case 'atrasado':
        return Colors.red;
      case 'completo':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  Future<void> loadData(int clienteId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _cliente = await _repo.getClienteById(clienteId);
      _pagos = await _repo.getPagos(clienteId);
      _cronograma = await _repo.getCronograma(clienteId);
      _historiales = await _repo.getHistoriales(clienteId);
      _cuotaSeleccionada = null;
    } catch (e) {
      debugPrint('🔴 [VM] Error en loadData: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCuota(int numero) {
    _cuotaSeleccionada = numero;
    debugPrint('🔔 [VM] cuotaSeleccionada = $numero');
    notifyListeners();
  }

  Future<bool> registrarPago({String? observaciones}) async {
    if (_cliente == null || _cuotaSeleccionada == null) return false;
    
    final numero = _cuotaSeleccionada!;
    final monto = numero == _cliente!.plazoDias
        ? _cliente!.ultimaCuota
        : _cliente!.cuotaDiaria;
    
    debugPrint('🔔 [VM] registrarPago -> cuota: $numero, monto: $monto');

    // Obtener ubicación antes de registrar el pago
    debugPrint('🔔 [VM] Obteniendo ubicación para el pago...');
    LocationData? ubicacion;
    try {
      ubicacion = await _locationService.getCurrentLocation();
      if (ubicacion != null) {
        debugPrint('✅ [VM] Ubicación obtenida: ${ubicacion.latitude}, ${ubicacion.longitude}');
      } else {
        debugPrint('⚠️ [VM] No se pudo obtener ubicación, continuando sin ella');
      }
    } catch (e) {
      debugPrint('❌ [VM] Error obteniendo ubicación: $e');
    }

    // Registrar pago con ubicación
    final ok = await _repo.registrarPago(
      _cliente!.id, 
      numero, 
      monto,
      latitud: ubicacion?.latitude,
      longitud: ubicacion?.longitude,
      direccion: ubicacion?.address,
    );
    
    debugPrint('🔔 [VM] resultado registrarPago: $ok');
    
    if (ok) {
      // Si hay observaciones, registrar evento
      if (observaciones != null && observaciones.isNotEmpty) {
        await registrarEvento(observaciones);
      }
      await loadData(_cliente!.id);
    }
    return ok;
  }

  Future<bool> registrarEvento(String descripcion) async {
    debugPrint('🔔 [VM] registrarEvento -> $descripcion');
    if (_cliente == null) return false;
    final ok = await _repo.registrarEvento(_cliente!.id, descripcion);
    debugPrint('🔔 [VM] resultado registrarEvento: $ok');
    return ok;
  }

  /// 1) Método para resetear antes de abrir el diálogo:
  void iniciarRefinanciamiento() {
    _montoAdicional = 0.0;
    _plazoRefinanciar = _cliente?.plazoDias ?? 12;
    _nuevoMontoPrestado = 0.0;
    _nuevoSaldoPendiente = 0.0;
    _nuevaCuotaDiaria = 0.0;
    _nuevaUltimaCuota = 0.0;
    notifyListeners();
  }

  // 2) Método principal de refinanciamiento:
  Future<bool> confirmarRefinanciamiento(double monto, int plazo) async {
    if (_cliente == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      // Obtener ubicación para el refinanciamiento
      debugPrint('🔔 [VM] Obteniendo ubicación para refinanciamiento...');
      LocationData? ubicacion;
      try {
        ubicacion = await _locationService.getCurrentLocation();
        if (ubicacion != null) {
          debugPrint('✅ [VM] Ubicación obtenida para refinanciamiento');
        }
      } catch (e) {
        debugPrint('❌ [VM] Error obteniendo ubicación: $e');
      }

      // Llamar a la función RPC con ubicación
      // NOTA: Esta función retorna void, no bool
      debugPrint('🔔 [VM] Enviando a RPC refinanciamiento: lat=${ubicacion?.latitude}, lng=${ubicacion?.longitude}, dir=${ubicacion?.address}');
      
      await _supabase.rpc(
        'abrir_nuevo_credito_con_ubicacion',
        params: {
          'p_cliente_id': _cliente!.id,
          'p_monto_solicitado': monto + (_cliente!.saldoPendiente.toDouble()),
          'p_plazo_dias': plazo,
          'p_fecha_primer_pago': DateTime.now().toIso8601String().split('T')[0],
          'p_latitud': ubicacion?.latitude,
          'p_longitud': ubicacion?.longitude,
          'p_direccion': ubicacion?.address,
        },
      );

      // Si llegamos aquí sin excepción, fue exitoso
      debugPrint('✅ [VM] Refinanciamiento exitoso');
      
      // Guarda evento en historial
      await registrarEvento(
          'Refinanciamiento: +S/${monto.toStringAsFixed(2)} a $plazo días');
      // Recarga datos desde cero
      await loadData(_cliente!.id);
      
      return true;
    } catch (e) {
      debugPrint('❌ [VM] Error en refinanciamiento: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────
  // 3) Setters para capturar la entrada del usuario en el diálogo:
  void setMontoAdicional(double monto) {
    _montoAdicional = monto;
    final base = _cliente?.saldoPendiente.toDouble() ?? 0.0;
    final plazo = _plazoRefinanciar;

    // 1) Unión: saldo actual + monto a solicitar
    final union = base + monto;
    debugPrint('🔍 [Refi] base=$base, montoSolicitar=$monto → union=$union');

    // 2) Tasa según plazo
    final tasa = plazo == 12 ? 10 : 20;
    debugPrint('🔍 [Refi] plazo=$plazo días → tasa=$tasa%');

    // 3) Nuevo total a pagar
    final totalPagar = union * (1 + tasa / 100);
    debugPrint('🔍 [Refi] totalPagar (con interés)=$totalPagar');

    // 4) Reparto en cuotas
    final diaria = (totalPagar / plazo).ceilToDouble();
    final ultima = totalPagar - diaria * (plazo - 1);
    debugPrint('🔍 [Refi] cuotaDiaria=$diaria, ultimaCuota=$ultima');

    // 5) Asignar a campos de preview
    _nuevoMontoPrestado = union;
    _nuevoSaldoPendiente = totalPagar;
    _nuevaCuotaDiaria = diaria;
    _nuevaUltimaCuota = ultima;

    notifyListeners();
  }

  void setPlazoRefinanciar(int plazo) {
    _plazoRefinanciar = plazo;
    notifyListeners();
  }

  // Setters
  void setNuevoMonto(double m) {
    _nuevoMontoSolicitado = m;
    notifyListeners();
  }

  void setNuevoPlazo(int p) {
    _nuevoPlazo = p;
    notifyListeners();
  }

  Future<void> pickNuevaFechaPrimerPago(BuildContext ctx) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      _nuevaFechaPrimerPago = d;
      notifyListeners();
    }
  }

  /// Llama al repo para crear el crédito y recarga datos
  Future<bool> confirmarNuevoCredito() async {
    debugPrint('🔔 [VM] confirmarNuevoCredito → '
        'monto=$_nuevoMontoSolicitado, plazo=$_nuevoPlazo, '
        'fecha=$_nuevaFechaPrimerPago');

    if (_cliente == null || _nuevaFechaPrimerPago == null) {
      debugPrint('⚠️ [VM] confirmarNuevoCredito: datos incompletos');
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // Obtener ubicación
      debugPrint('🔔 [VM] Obteniendo ubicación para nuevo crédito...');
      LocationData? ubicacion;
      try {
        ubicacion = await _locationService.getCurrentLocation();
      } catch (e) {
        debugPrint('❌ [VM] Error obteniendo ubicación: $e');
      }

      // Usar la función RPC con ubicación
      // NOTA: Esta función retorna void, no bool
      debugPrint('🔔 [VM] Enviando a RPC nuevo crédito: lat=${ubicacion?.latitude}, lng=${ubicacion?.longitude}, dir=${ubicacion?.address}');
      
      await _supabase.rpc(
        'abrir_nuevo_credito_con_ubicacion',
        params: {
          'p_cliente_id': _cliente!.id,
          'p_monto_solicitado': _nuevoMontoSolicitado,
          'p_plazo_dias': _nuevoPlazo,
          'p_fecha_primer_pago': _nuevaFechaPrimerPago!.toIso8601String().split('T')[0],
          'p_latitud': ubicacion?.latitude,
          'p_longitud': ubicacion?.longitude,
          'p_direccion': ubicacion?.address,
        },
      );

      // Si llegamos aquí sin excepción, fue exitoso
      debugPrint('✅ [VM] Nuevo crédito creado exitosamente');
      
      // Recarga datos
      await loadData(_cliente!.id);
      
      return true;
    } catch (e) {
      debugPrint('❌ [VM] Error en nuevo crédito: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Agregar justo después de confirmarNuevoCredito()
  void iniciarNuevoCredito() {
    _nuevoMontoSolicitado = 0.0;
    _nuevoPlazo = 12;
    _nuevaFechaPrimerPago = null;
    notifyListeners();
  }
}
