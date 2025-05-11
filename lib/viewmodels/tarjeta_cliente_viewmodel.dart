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
  HistorialRead? _historial;
  int? _cuotaSeleccionada;

  // Getters
  bool get isLoading => _isLoading;
  ClienteDetailRead? get cliente => _cliente;
  List<PagoRead> get pagos => List.unmodifiable(_pagos);
  List<CronogramaRead> get cronograma => List.unmodifiable(_cronograma);
  HistorialRead? get historial => _historial;
  int? get cuotaSeleccionada => _cuotaSeleccionada;

  // Carga inicial de datos
  Future<void> loadData(int clienteId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _cliente = await _repo.getClienteById(clienteId);
      _pagos = await _repo.getPagos(clienteId);
      _cronograma = await _repo.getCronograma(clienteId);
      _historial = await _repo.getHistorial(clienteId);
      _cuotaSeleccionada = null;
    } catch (e) {
      // Manejo de errores: podrías notificar con un callback o log
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Seleccionar cuota para registrar
  void selectCuota(int numero) {
    _cuotaSeleccionada = numero;
    notifyListeners();
  }

  // Registrar pago: usa el monto del detalle
  Future<bool> registrarPago() async {
    if (_cliente == null || _cuotaSeleccionada == null) return false;

    final monto = _cuotaSeleccionada == _cliente!.plazoDias
        ? _cliente!.ultimaCuota
        : _cliente!.cuotaDiaria;

    final ok = await _repo.registrarPago(
      _cliente!.id,
      _cuotaSeleccionada!,
      monto,
    );
    if (ok) {
      await loadData(_cliente!.id);
    }
    return ok;
  }

  // Registrar evento si hay observaciones
  Future<bool> registrarEvento(String descripcion) async {
    if (_cliente == null) return false;
    return _repo.registrarEvento(_cliente!.id, descripcion);
  }
}
