import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../tarjeta_cliente/tarjeta_cliente_screen.dart'; // asegúrate que esta ruta sea correcta

class ListaDeClientesScreen extends StatefulWidget {
  const ListaDeClientesScreen({super.key});

  @override
  State<ListaDeClientesScreen> createState() => _ListaDeClientesScreenState();
}

class _ListaDeClientesScreenState extends State<ListaDeClientesScreen> {
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _clientes = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchClientes();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Carga inicial
  Future<void> _fetchClientes() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('clientes')
          .select()
          .order('id', ascending: true)
          .range(0, _pageSize - 1); // primeros 20
      if (!mounted) return;
      setState(() {
        _clientes = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando clientes: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Paginado al llegar al final
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
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
          .from('clientes')
          .select()
          .order('id', ascending: true)
          .range(from, to);
      final more = List<Map<String, dynamic>>.from(data);
      if (more.isNotEmpty && mounted) {
        setState(() {
          _clientes.addAll(more);
        });
      }
    } catch (e) {
      // opcional: mostrar error
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista de Clientes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _clientes.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _clientes.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final c = _clientes[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TarjetaClienteScreen(clienteId: c['id']),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 6,
                    color: const Color.fromARGB(
                        255, 255, 255, 255), // azul claro suave
                    child: ListTile(
                      title: Text(
                        c['nombre'] as String,
                        style: const TextStyle(
                          color: Color.fromARGB(255, 7, 0, 0), // texto oscuro
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teléfono: ${c['telefono']}',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 7, 0, 0)),
                          ),
                          Text(
                            'Dirección: ${c['direccion']}',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 7, 0, 0)),
                          ),
                          Text(
                            'Negocio: ${c['negocio']}',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 7, 0, 0)),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
