// lib/viewmodels/clientes_pendientes_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/cliente_read.dart';
import '../repositories/cliente_repository.dart';

class ClientesPendientesViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

  ClientesPendientesViewModel(this._repo) {
    loadInitial();
  }

  List<ClienteRead> _all = [];
  String _searchTerm = '';
  bool isLoading = false;
  bool isLoadingMore = false;
  int _page = 0;
  static const int _pageSize = 20;

  Future<void> loadInitial() async {
    isLoading = true;
    notifyListeners();
    _page = 0;
    _all = await _repo.fetchClientesPendientes(page: 0, size: _pageSize);
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();
    _page++;
    final more =
        await _repo.fetchClientesPendientes(page: _page, size: _pageSize);
    if (more.isNotEmpty) _all.addAll(more);
    isLoadingMore = false;
    notifyListeners();
  }

  List<ClienteRead> get filteredClientes {
    if (_searchTerm.isEmpty) return _all;
    final q = _searchTerm.toLowerCase();
    return _all
        .where((c) =>
            c.nombre.toLowerCase().contains(q) ||
            c.telefono.toLowerCase().contains(q) ||
            c.negocio.toLowerCase().contains(q))
        .toList();
  }

  Future<void> updateSearch(String term) async {
    _searchTerm = term;
    notifyListeners();
    if (term.isEmpty) {
      await loadInitial();
    }
  }
}
