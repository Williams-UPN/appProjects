import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tarjeta_cliente/tarjeta_cliente_screen.dart'; // Ajusta la ruta si es necesario

class ListaDeClientesScreen extends StatefulWidget {
  const ListaDeClientesScreen({super.key});

  @override
  State<ListaDeClientesScreen> createState() => _ListaDeClientesScreenState();
}

class _ListaDeClientesScreenState extends State<ListaDeClientesScreen> {
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
    _fetchClientes();
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

  Future<void> _fetchClientes() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('v_clientes_con_estado')
          .select(
              'id, nombre, telefono, direccion, negocio, estado_real, dias_reales')
          .order('id', ascending: true)
          .range(0, _pageSize - 1);
      if (!mounted) return;
      _clientes = List<Map<String, dynamic>>.from(data);
      _page = 0;
      _applyLocalFilter();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando clientes: $e')),
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
              'id, nombre, telefono, direccion, negocio, estado_real, dias_reales')
          .order('id', ascending: true)
          .range(from, to);
      final more = List<Map<String, dynamic>>.from(data);
      if (more.isNotEmpty && mounted) {
        _clientes.addAll(more);
        _applyLocalFilter();
      }
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Clientes')),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Buscar cliente…',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_searchTerm.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _searchTerm = '');
                        _applyLocalFilter();
                      },
                      child:
                          const Icon(Icons.close, size: 20, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          // Lista de tarjetas
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
                      return InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TarjetaClienteScreen(clienteId: c['id']),
                            ),
                          );
                          await _fetchClientes();
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 4,
                          child: ListTile(
                            title: Text(
                              c['nombre'] as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Teléfono: ${c['telefono']}'),
                                Text('Dirección: ${c['direccion']}'),
                                // Nuevo Row con spaceBetween
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Negocio: ${c['negocio'] ?? '-'}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildStatusChip(
                                        c['estado_real'] as String),
                                  ],
                                ),
                              ],
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
