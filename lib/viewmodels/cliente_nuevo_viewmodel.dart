// lib/viewmodels/cliente_nuevo_viewmodel.dart

import 'package:flutter/foundation.dart';
import '../models/cliente.dart';
import '../repositories/cliente_repository.dart';

class ClienteNuevoViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

  // Constructor
  ClienteNuevoViewModel(this._repo);

  int _currentStep = 0;
  bool _isLoading = false;

  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;

  void avanzarStep() {
    if (_currentStep < 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void retrocederStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  Future<bool> guardarCliente(Cliente cliente) async {
    _isLoading = true;
    notifyListeners();

    // --- INSTRUMENTACIÓN PARA DEPURAR ---
    debugPrint('🔔 [VM] Intentando crear cliente: ${cliente.nombre}');
    final success = await _repo.crearCliente(cliente);
    debugPrint('🔔 [VM] Resultado crearCliente: $success');
    // --------------------------------------

    _isLoading = false;
    notifyListeners();
    return success;
  }
}
