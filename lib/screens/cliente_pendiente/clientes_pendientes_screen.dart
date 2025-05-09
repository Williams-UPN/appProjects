// lib/screens/cliente_pendiente/clientes_pendientes_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cliente_read.dart';
import '../../viewmodels/clientes_pendientes_viewmodel.dart';
import '../tarjeta_cliente/tarjeta_cliente_screen.dart';
import '../../widgets/relief_star.dart'; // Asegúrate de tener este widget

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ClientesPendientesViewModel>().loadInitial();
    });
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
    Color color;
    String label;
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
        color = const Color.fromARGB(255, 23, 211, 29);
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
      body: Consumer<ClientesPendientesViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = vm.filteredClientes;

          return Column(
            children: [
              // Barra de búsqueda redondeada (sin cambios)
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
                              });
                              vm.updateSearch('');
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

              // Listado paginado
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
                    final score = c.scoreActual;
                    final isNew = !c.hasHistory;
                    final stars = isNew ? 5 : _scoreToStars(score);
                    final scoreLabel =
                        isNew ? '¡nuevo!' : _labelParaScore(score);
                    final scoreColor =
                        isNew ? Colors.grey : _colorParaScore(score);

                    return Card(
                      // ────────────── AÑADIDO: fondo pastel-azul ──────────────
                      color: Colors.blue.shade50,
                      // Si quieres un azul aún más claro prueba:
                      // color: Colors.blue.shade25, o Colors.blue.shade100
                      // ────────────────────────────────────────────────────────

                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 2, // tu sombreado original
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            // ─────────── Estrellas con ReliefStar ───────────
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(5, (i) {
                                return ReliefStar(
                                  filled: i < stars,
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
                              // IZQUIERDA: datos
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
                              // DERECHA: score + estado + días atraso
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      scoreLabel,
                                      style: TextStyle(
                                          color: scoreColor, fontSize: 12),
                                    ),
                                    _buildStatusChip(c.estadoReal),
                                    Text(
                                      '${c.diasReales} días atraso',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.red),
                                    ),
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
