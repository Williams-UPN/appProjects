// lib/screens/lista_de_clientes/lista_de_clientes_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cliente_read.dart';
import '../../viewmodels/lista_clientes_viewmodel.dart';
import '../tarjeta_cliente/tarjeta_cliente_screen.dart';

class ListaDeClientesScreen extends StatefulWidget {
  const ListaDeClientesScreen({super.key});

  @override
  State<ListaDeClientesScreen> createState() => _ListaDeClientesScreenState();
}

class _ListaDeClientesScreenState extends State<ListaDeClientesScreen> {
  late final ScrollController _scrollController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final vm = context.read<ListaClientesViewModel>();
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100) {
          vm.loadMore();
        }
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Color _colorParaEstado(String estado) {
    switch (estado) {
      case 'proximo':
        return Colors.blue;
      case 'al_dia':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'atrasado':
        return Colors.red;
      case 'completo':
        return const Color.fromARGB(255, 23, 211, 29);
      default:
        return Colors.grey;
    }
  }

  String _labelParaEstado(String estado) {
    switch (estado) {
      case 'proximo':
        return 'Próximo';
      case 'al_dia':
        return 'Al día';
      case 'pendiente':
        return 'Vence hoy';
      case 'atrasado':
        return 'Atrasado';
      case 'completo':
        return 'Completado';
      default:
        return '';
    }
  }

  Widget _buildStatusChip(String estado) {
    final color = _colorParaEstado(estado);
    final label = _labelParaEstado(estado);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  int _scoreToStars(int score) {
    if (score >= 90) return 5;
    if (score >= 75) return 4;
    if (score >= 50) return 3;
    if (score >= 25) return 2;
    if (score >= 1) return 1;
    return 0;
  }

  Widget _buildStarRating(int stars) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < stars ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  String _labelParaScore(int score) {
    if (score >= 90) return 'Excelente';
    if (score >= 75) return 'Buen pagador';
    if (score >= 50) return 'Riesgo medio';
    if (score >= 25) return 'Riesgo alto';
    return 'Incumplidor';
  }

  Color _colorParaScore(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 50) return Colors.orange;
    if (score >= 25) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Clientes')),
      body: Consumer<ListaClientesViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = vm.filteredClientes;

          return Column(
            children: [
              // Barra de búsqueda con estilo redondeado
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchTerm.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              setState(() {
                                _searchTerm = '';
                                vm.updateSearch('');
                              });
                            },
                            child: const Icon(Icons.close),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) {
                    _searchTerm = v.toLowerCase();
                    vm.updateSearch(_searchTerm);
                  },
                ),
              ),

              // Listado con paginación
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length + (vm.isLoadingMore ? 1 : 0),
                  itemBuilder: (_, index) {
                    if (index >= list.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final ClienteRead c = list[index];
                    final isNew = !c.hasHistory;
                    final stars = isNew ? 5 : _scoreToStars(c.scoreActual);
                    final label =
                        isNew ? '¡nuevo!' : _labelParaScore(c.scoreActual);
                    final color =
                        isNew ? Colors.grey : _colorParaScore(c.scoreActual);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TarjetaClienteScreen(clienteId: c.id),
                            ),
                          );
                          vm.loadInitial();
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.nombre,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            _buildStarRating(stars),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Teléfono: ${c.telefono}'),
                            Text('Dirección: ${c.direccion}'),
                            Text('Negocio: ${c.negocio}'),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(color: color, fontSize: 12),
                                ),
                                _buildStatusChip(c.estadoReal),
                              ],
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
