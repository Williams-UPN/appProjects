import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tarjeta_cliente/tarjeta_cliente_screen.dart';

class ClientesPendientesScreen extends StatefulWidget {
  const ClientesPendientesScreen({super.key});

  @override
  State<ClientesPendientesScreen> createState() =>
      _ClientesPendientesScreenState();
}

class _ClientesPendientesScreenState extends State<ClientesPendientesScreen> {
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _filteredClientes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 0;
  static const int _pageSize = 20;
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchClientesPendientes();
    _scrollController.addListener(_onScroll);
    _searchCtrl.addListener(() {
      setState(() {
        _searchTerm = _searchCtrl.text.toLowerCase();
        _applyLocalFilter();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _fetchClientesPendientes() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('v_clientes_con_estado')
          .select(
            '''
id,
nombre,
telefono,
direccion,
negocio,
estado_real,
dias_reales,
score_actual
''',
          )
          .gt('dias_reales', 0) // solo atrasados
          .order('dias_reales') // ordenar por días de atraso ascendente
          .order('id') // luego por id para paginación consistente
          .range(0, _pageSize - 1);
      if (!mounted) return;
      _clientes = List<Map<String, dynamic>>.from(data);
      _page = 0;
      _applyLocalFilter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar pendientes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    final from = _page * _pageSize;
    final to = from + _pageSize - 1;
    try {
      final data = await supabase
          .from('v_clientes_con_estado')
          .select(
            '''
id,
nombre,
telefono,
direccion,
negocio,
estado_real,
dias_reales,
score_actual
''',
          )
          .gt('dias_reales', 0)
          .order('dias_reales')
          .order('id')
          .range(from, to);
      final more = List<Map<String, dynamic>>.from(data);
      if (more.isNotEmpty && mounted) {
        _clientes.addAll(more);
        _applyLocalFilter();
      }
    } catch (_) {
      // opcional: manejar error
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _applyLocalFilter() {
    if (_searchTerm.isEmpty) {
      _filteredClientes = List.from(_clientes);
    } else {
      _filteredClientes = _clientes.where((c) {
        final nombre = (c['nombre'] as String).toLowerCase();
        final telefono = (c['telefono'] as String).toLowerCase();
        final negocio = (c['negocio'] as String? ?? '').toLowerCase();
        return nombre.contains(_searchTerm) ||
            telefono.contains(_searchTerm) ||
            negocio.contains(_searchTerm);
      }).toList();
    }
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
      appBar: AppBar(title: const Text('Clientes Atrasados')),
      body: Column(
        children: [
          // Barra de búsqueda
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
                          setState(() {
                            _searchTerm = '';
                            _applyLocalFilter();
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
            ),
          ),

          // Lista de clientes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount:
                        _filteredClientes.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _filteredClientes.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final c = _filteredClientes[index];
                      final score = (c['score_actual'] as int?) ?? 0;
                      final stars = _scoreToStars(score);
                      final categoryLabel = _labelParaScore(score);
                      final categoryColor = _colorParaScore(score);

                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TarjetaClienteScreen(clienteId: c['id']),
                            ),
                          );
                          _fetchClientesPendientes();
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 2,
                          child: ListTile(
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    c['nombre'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                _buildStarRating(stars),
                              ],
                            ),
                            subtitle: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text("Tel: ${c['telefono']}"),
                                        Text("Dir: ${c['direccion']}"),
                                        Text("Neg: ${c['negocio'] ?? '-'}"),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          categoryLabel,
                                          style: TextStyle(
                                            color: categoryColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                        _buildStatusChip(
                                            c['estado_real'] as String),
                                        Text(
                                          '${c['dias_reales']} días atraso',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
