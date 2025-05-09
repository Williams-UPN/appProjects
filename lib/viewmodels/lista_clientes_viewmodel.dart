// lib/viewmodels/lista_clientes_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/cliente_read.dart';
import '../repositories/cliente_repository.dart';

class ListaClientesViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

  ListaClientesViewModel(this._repo) {
    loadInitial();
  }

  /// La lista de clientes recibida del backend
  List<ClienteRead> clientes = [];

  /// Estado de carga inicial
  bool isLoading = false;

  /// Estado de carga de páginas adicionales
  bool isLoadingMore = false;

  /// Término de búsqueda actual
  String searchTerm = '';

  /// Paginación interna
  int _page = 0;
  static const int _pageSize = 20;

  /// Carga la primera página de clientes
  Future<void> loadInitial() async {
    isLoading = true;
    notifyListeners();

    _page = 0;
    try {
      clientes = await _repo.fetchClientes(page: 0, size: _pageSize);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Carga la siguiente página y la añade al final
  Future<void> loadMore() async {
    if (isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();

    _page++;
    try {
      final mas = await _repo.fetchClientes(page: _page, size: _pageSize);
      if (mas.isNotEmpty) {
        clientes.addAll(mas);
      }
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Actualiza el término de búsqueda y realiza una nueva consulta
  Future<void> updateSearch(String term) async {
    searchTerm = term;
    notifyListeners();

    if (term.isEmpty) {
      // si el término queda vacío, volvemos al listado completo
      await loadInitial();
    } else {
      isLoading = true;
      notifyListeners();

      try {
        clientes = await _repo.searchClientes(
          term: term,
          page: 0,
          size: _pageSize,
        );
      } finally {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Opcional: filtrado local si prefieres no recargar backend
  List<ClienteRead> get filteredClientes {
    if (searchTerm.isEmpty) return clientes;
    final lower = searchTerm.toLowerCase();
    return clientes.where((c) {
      return c.nombre.toLowerCase().contains(lower) ||
          c.telefono.toLowerCase().contains(lower) ||
          c.negocio.toLowerCase().contains(lower);
    }).toList();
  }
}
