// lib/viewmodels/lista_clientes_viewmodel.dart

import 'package:flutter/material.dart';
import '../models/cliente_read.dart';
import '../repositories/cliente_repository.dart';

class ListaClientesViewModel extends ChangeNotifier {
  final ClienteRepository _repo;

  ListaClientesViewModel(this._repo) {
    loadInitial();
  }

  List<ClienteRead> clientes = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  String searchTerm = '';
  int _page = 0;
  static const int _pageSize = 20;

  Future<void> loadInitial() async {
    isLoading = true;

    _page = 0;
    if (searchTerm.isNotEmpty) {
      searchTerm = '';
    }

    notifyListeners();

    try {
      clientes = await _repo.fetchClientes(page: 0, size: _pageSize);
    } finally {
      isLoading = false;
    }
    notifyListeners();
  }

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

  Future<void> updateSearch(String term) async {
    if (term == searchTerm && term.isNotEmpty) {
      return;
    }

    searchTerm =
        term.toLowerCase(); // Normalizar a minúsculas aquí consistentemente

    if (searchTerm.isEmpty) {
      notifyListeners(); // Notificar que searchTerm ha cambiado a vacío
      await loadInitial(); // loadInitial ya maneja isLoading y notifica
    } else {
      isLoading = true;
      notifyListeners(); // Notificar que searchTerm cambió y estamos cargando

      _page = 0; // Resetear la página para una nueva búsqueda
      try {
        clientes = await _repo.searchClientes(
          term: searchTerm, // Usar this.searchTerm ya normalizado
          page: _page, // Usar _page reseteado
          size: _pageSize,
        );
      } finally {
        isLoading = false;
        // notifyListeners(); // El notifyListeners al final de updateSearch es suficiente
      }
    }
    notifyListeners(); // Notificar después de todas las operaciones de búsqueda/carga
  }

  List<ClienteRead> get filteredClientes {
    if (searchTerm.isEmpty) return clientes;
    return clientes.where((c) {
      return c.nombre
              .toLowerCase()
              .contains(searchTerm) || // usar searchTerm directamente
          (c.telefono.toLowerCase().contains(
              searchTerm)) || // Añadir chequeo de nulidad para telefono
          (c.negocio
              .toLowerCase()
              .contains(searchTerm)); // Añadir chequeo de nulidad para negocio
    }).toList();
  }
}
