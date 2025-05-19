// lib/viewmodels/clientes_pendientes_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/cliente_read.dart';
import '../repositories/cliente_repository.dart';

class ClientesPendientesViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

  ClientesPendientesViewModel(this._repo) {
    loadInitial();
  }

  List<ClienteRead> _clientesActuales = [];
  String _currentSearchTerm = '';
  bool isLoading = false;
  bool isLoadingMore = false;
  int _page = 0;
  static const int _pageSize = 20;

  List<ClienteRead> get filteredClientes {
    if (_currentSearchTerm.isEmpty) {
      return _clientesActuales;
    }
    return _clientesActuales.where((c) {
      final nombre = c.nombre.toLowerCase();
      final telefono = c.telefono.toLowerCase();
      final negocio = c.negocio.toLowerCase();
      return nombre.contains(_currentSearchTerm) ||
          telefono.contains(_currentSearchTerm) ||
          negocio.contains(_currentSearchTerm);
    }).toList();
  }

  String get currentSearchTermValue => _currentSearchTerm;

  Future<void> loadInitial() async {
    isLoading = true;
    _currentSearchTerm = '';
    _page = 0;
    notifyListeners();

    try {
      _clientesActuales =
          await _repo.fetchClientesPendientes(page: _page, size: _pageSize);
    } catch (e) {
      _clientesActuales = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || isLoading) return;
    isLoadingMore = true;
    notifyListeners();

    _page++;
    try {
      List<ClienteRead> moreClientes;
      if (_currentSearchTerm.isEmpty) {
        moreClientes =
            await _repo.fetchClientesPendientes(page: _page, size: _pageSize);
      } else {
        moreClientes = [];
      }

      if (moreClientes.isNotEmpty) {
        _clientesActuales.addAll(moreClientes);
      } else {
        if (_currentSearchTerm.isEmpty) {
          _page--; // Revertir solo si no hay más páginas y no hay búsqueda
        }
      }
    } catch (e) {
      if (_currentSearchTerm.isEmpty) _page--;
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> updateSearch(String term) async {
    final newSearchTerm = term.toLowerCase();
    _currentSearchTerm = newSearchTerm;
    _page = 0;

    notifyListeners();

    if (_currentSearchTerm.isEmpty) {
      await loadInitial();
    } else {}
  }
}
