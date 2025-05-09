// lib/viewmodels/clientes_pendientes_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/cliente_read.dart';
import '../repositories/cliente_repository.dart';

class ClientesPendientesViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

  ClientesPendientesViewModel(this._repo) {
    loadInitial();
  }

  /// Datos del backend
  List<ClienteRead> _all = [];
  List<ClienteRead> get filteredClientes {
    if (_searchTerm.isEmpty) return _all;
    final lower = _searchTerm.toLowerCase();
    return _all.where((c) {
      return c.nombre.toLowerCase().contains(lower) ||
          c.telefono.toLowerCase().contains(lower) ||
          c.negocio.toLowerCase().contains(lower);
    }).toList();
  }

  bool isLoading = false;
  bool isLoadingMore = false;
  String _searchTerm = '';
  int _page = 0;
  static const int _pageSize = 20;

  /// Primera carga: trae sólo clientes con atraso (>0 días)
  Future<void> loadInitial() async {
    isLoading = true;
    notifyListeners();

    _page = 0;
    try {
      _all = await _repo.fetchClientesPendientes(page: 0, size: _pageSize);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Trae página siguiente
  Future<void> loadMore() async {
    if (isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();

    _page++;
    try {
      final mas =
          await _repo.fetchClientesPendientes(page: _page, size: _pageSize);
      if (mas.isNotEmpty) _all.addAll(mas);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Actualiza búsqueda (y recarga o filtra)
  Future<void> updateSearch(String term) async {
    _searchTerm = term;
    notifyListeners();

    if (term.isEmpty) {
      await loadInitial();
    } else {
      // si prefieres, podrías hacer backend search aquí:
      // _all = await _repo.searchClientesPendientes(term, page: 0, size: _pageSize);
      notifyListeners();
    }
  }
}
