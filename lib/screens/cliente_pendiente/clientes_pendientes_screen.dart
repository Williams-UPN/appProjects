// lib/screens/cliente_pendiente/clientes_pendientes_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/clientes_pendientes_viewmodel.dart';
import '../tarjeta_cliente/tarjeta_cliente_screen.dart';
import '../../widgets/relief_star.dart';

class ClientesPendientesScreen extends StatefulWidget {
  const ClientesPendientesScreen({super.key});
  @override
  State<ClientesPendientesScreen> createState() =>
      _ClientesPendientesScreenState();
}

class _ClientesPendientesScreenState extends State<ClientesPendientesScreen> {
  late final ScrollController _scrollController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        final vm = context.read<ClientesPendientesViewModel>();
        if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100) {
          vm.loadMore();
        }
      });
    _searchCtrl.addListener(() {
      final v = _searchCtrl.text.toLowerCase();
      _searchTerm = v;
      context.read<ClientesPendientesViewModel>().updateSearch(v);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int _scoreToStars(int score) {
    if (score >= 90) return 5;
    if (score >= 75) return 4;
    if (score >= 50) return 3;
    if (score >= 25) return 2;
    if (score >= 1) return 1;
    return 0;
  }

  Widget _buildStatusChip(String estado) {
    late Color color;
    late String label;
    switch (estado) {
      case 'proximo':
        color = Colors.blue;
        label = 'Próximo';
        break;
      case 'al_dia':
        color = Colors.green;
        label = 'Al día';
        break;
      case 'pendiente':
        color = Colors.orange;
        label = 'Vence hoy';
        break;
      case 'atrasado':
        color = Colors.red;
        label = 'Atrasado';
        break;
      case 'completo':
        color = Colors.green;
        label = 'Completado';
        break;
      default:
        color = Colors.grey;
        label = '';
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
      ],
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
      appBar: AppBar(title: const Text('Clientes Atrasados')),
      body: Column(
        children: [
          // Barra de búsqueda — sin cambios en estilo ni lógica
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar cliente…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchTerm = '');
                          context
                              .read<ClientesPendientesViewModel>()
                              .updateSearch('');
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
            ),
          ),

          // Listado de pendientes: Consumer acotado solo al ListView
          Expanded(
            child: Consumer<ClientesPendientesViewModel>(
              builder: (_, vm, __) {
                if (vm.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = vm.filteredClientes;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length + (vm.isLoadingMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i >= list.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final c = list[i];
                    final stars = _scoreToStars(c.scoreActual);
                    final scoreLabel = c.hasHistory
                        ? _labelParaScore(c.scoreActual)
                        : '¡nuevo!';
                    final scoreColor = c.hasHistory
                        ? _colorParaScore(c.scoreActual)
                        : Colors.grey;

                    return Card(
                      color: Colors.blue.shade50,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        onTap: () {
                          // capturo vm y controller antes
                          final vmLocal =
                              context.read<ClientesPendientesViewModel>();
                          final controller = _searchCtrl;

                          // navego y vuelvo en .then recargo todo
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TarjetaClienteScreen(clienteId: c.id),
                            ),
                          ).then((_) {
                            // limpio búsqueda
                            controller.clear();
                            setState(() => _searchTerm = '');
                            // recargo desde cero
                            vmLocal.loadInitial();
                          });
                        },
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(c.nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (j) {
                                return ReliefStar(
                                  filled: j < stars,
                                  size: 16,
                                );
                              }),
                            ),
                          ],
                        ),
                        subtitle: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tel: ${c.telefono}'),
                                    Text('Dir: ${c.direccion}'),
                                    Text('Neg: ${c.negocio}'),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(scoreLabel,
                                        style: TextStyle(
                                            color: scoreColor, fontSize: 12)),
                                    _buildStatusChip(c.estadoReal),
                                    Text('${c.diasReales} días atraso',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
