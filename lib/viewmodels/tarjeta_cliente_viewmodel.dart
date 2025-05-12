// lib/viewmodels/tarjeta_cliente_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/cliente_detail_read.dart';
import '../models/pago_read.dart';
import '../models/cronograma_read.dart';
import '../models/historial_read.dart';
import '../repositories/cliente_repository.dart';

class TarjetaClienteViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

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

  /// 1) Estado de crédito completo
  bool get isCreditComplete => _cliente?.estadoReal == 'completo';

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

  Future<bool> registrarPago() async {
    if (_cliente == null || _cuotaSeleccionada == null) return false;
    final numero = _cuotaSeleccionada!;
    final monto = numero == _cliente!.plazoDias
        ? _cliente!.ultimaCuota
        : _cliente!.cuotaDiaria;
    debugPrint('🔔 [VM] registrarPago -> cuota: $numero, monto: $monto');

    final ok = await _repo.registrarPago(_cliente!.id, numero, monto);
    debugPrint('🔔 [VM] resultado registrarPago: $ok');
    if (ok) {
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
    // 1) Monto que ingresa el usuario
    _montoAdicional = 0.0;

    // 2) El plazo original (12 o 24)
    _plazoRefinanciar = _cliente?.plazoDias ?? 12;

    // 3) Valores “base” para mostrar antes de teclear nada:
    _nuevoMontoPrestado = 0.0;
    _nuevoSaldoPendiente = 0.0;
    _nuevaCuotaDiaria = 0.0;

    notifyListeners();
  }

  // 2) Método principal de refinanciamiento:
  Future<bool> confirmarRefinanciamiento(double monto, int plazo) async {
    if (_cliente == null) return false;
    _isLoading = true;
    notifyListeners();

    // 1) Llamada a repo (dispara triggers en la BD)
    final ok = await _repo.refinanciar(_cliente!.id, monto, plazo);

    if (ok) {
      // 2) Guarda evento en historial
      await registrarEvento(
          'Refinanciamiento: +S/${monto.toStringAsFixed(2)} a $plazo días');
      // 3) Recarga datos desde cero
      await loadData(_cliente!.id);
    }

    _isLoading = false;
    notifyListeners();
    return ok;
  }

  // ─────────────────────────────────────────────────────
  // 3) Setters para capturar la entrada del usuario en el diálogo:
  void setMontoAdicional(double monto) {
    _montoAdicional = monto;

    // 1) Base: saldo pendiente actual
    final base = _cliente?.saldoPendiente.toDouble() ?? 0.0;

    // 2) Nuevo monto prestado = base + monto adicional
    _nuevoMontoPrestado = base + monto;

    // 3) Nuevo saldo pendiente = mismo que el nuevo monto prestado
    _nuevoSaldoPendiente = _nuevoMontoPrestado;

    // 4) Nueva cuota diaria = ceil(nuevoSaldo / plazo original)
    final plazo = _cliente?.plazoDias.toDouble() ?? 12.0;
    _nuevaCuotaDiaria = (_nuevoSaldoPendiente / plazo).ceilToDouble();

    notifyListeners();
  }

  void setPlazoRefinanciar(int plazo) {
    _plazoRefinanciar = plazo;
    notifyListeners();
  }
}
