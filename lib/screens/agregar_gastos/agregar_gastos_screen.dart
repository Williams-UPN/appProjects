// lib/screens/agregar_gastos/agregar_gastos_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/agregar_gastos_viewmodel.dart';

class AgregarGastosScreen extends StatefulWidget {
  const AgregarGastosScreen({super.key});

  @override
  State<AgregarGastosScreen> createState() => _AgregarGastosScreenState();
}

class _AgregarGastosScreenState extends State<AgregarGastosScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _montoController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();

  final List<String> _categorias = ['Gasolina', 'Teléfono', 'Comida', 'Otro'];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late ExpansionTileController _expansionController;

  @override
  void initState() {
    super.initState();
    _expansionController = ExpansionTileController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _montoController.dispose();
    _descripcionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _limpiarFormulario() {
    _montoController.clear();
    _descripcionController.clear();
    context.read<AgregarGastosViewModel>().limpiarFormulario();
    _animationController.reset();
  }

  Future<void> _mostrarOpcionesFoto(BuildContext context) async {
    final vm = context.read<AgregarGastosViewModel>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seleccionar foto (ultra-ligera)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              subtitle: const Text('Se optimizará automáticamente'),
              onTap: () async {
                Navigator.pop(context);
                await vm.capturarFoto(fromCamera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de galería'),
              subtitle: const Text('Se reducirá el tamaño'),
              onTap: () async {
                Navigator.pop(context);
                await vm.capturarFoto(fromCamera: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarGasto() async {
    final vm = context.read<AgregarGastosViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    // Obtener ubicación si es posible
    await vm.obtenerUbicacion();

    // Intentar guardar
    final success = await vm.guardarGasto();

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('💾 Gasto guardado exitosamente (foto ultra-ligera)'),
          backgroundColor: Color(0xFF90CAF9),
        ),
      );
      _limpiarFormulario();
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('❌ Error al guardar el gasto'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agregar Gastos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.1),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () {
          // Cerrar el teclado al tocar fuera
          FocusScope.of(context).unfocus();
        },
        child: Consumer<AgregarGastosViewModel>(
          builder: (context, vm, child) {
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Categoría ExpansionTile
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              controller: _expansionController,
                              title: Text(
                                vm.categoriaSeleccionada ??
                                    'Seleccione una categoría',
                                style: TextStyle(
                                  color: vm.categoriaSeleccionada != null
                                      ? Colors.black87
                                      : Colors.black54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_drop_down_circle,
                                color: Color(0xFF90CAF9),
                              ),
                              children: _categorias.map((categoria) {
                                return ListTile(
                                  title: Text(
                                    categoria,
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onTap: () async {
                                    if (vm.categoriaSeleccionada != null &&
                                        categoria != vm.categoriaSeleccionada) {
                                      await _animationController.reverse();
                                      _montoController.clear();
                                      _descripcionController.clear();
                                    }
                                    vm.setCategoria(categoria);
                                    _animationController.forward();
                                    _expansionController.collapse();
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        // Mostrar error de categoría si existe
                        if (vm.errorCategoria != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              vm.errorCategoria!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          ),

                        // Campos que aparecen después de seleccionar categoría
                        if (vm.categoriaSeleccionada != null)
                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                const SizedBox(height: 20),

                                // Monto TextField
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  child: TextField(
                                    controller: _montoController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Monto',
                                      labelStyle: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87),
                                      hintText: 'S/ 0.00',
                                      hintStyle:
                                          TextStyle(color: Colors.black38),
                                      border: InputBorder.none,
                                      prefixText: 'S/ ',
                                      prefixStyle: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      errorText: vm.errorMonto,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    onChanged: (value) {
                                      final monto =
                                          double.tryParse(value) ?? 0.0;
                                      vm.setMonto(monto);
                                    },
                                  ),
                                ),

                                // Campo Descripción (Visible solo si categoría es "Otro")
                                if (vm.categoriaSeleccionada == 'Otro') ...[
                                  const SizedBox(height: 20),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    child: TextField(
                                      controller: _descripcionController,
                                      maxLines: 3,
                                      decoration: InputDecoration(
                                        labelText: 'Descripción',
                                        labelStyle: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        hintText: 'Detalle del gasto...',
                                        hintStyle:
                                            TextStyle(color: Colors.black38),
                                        border: InputBorder.none,
                                        errorText: vm.errorDescripcion,
                                      ),
                                      style: const TextStyle(fontSize: 16),
                                      onChanged: vm.setDescripcion,
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),

                                // Botón Adjuntar Foto
                                Container(
                                  decoration: BoxDecoration(
                                    color: vm.fotoSeleccionada != null
                                        ? Colors.green.shade100
                                        : const Color(0xFFBBDEFB),
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          _mostrarOpcionesFoto(context),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              vm.fotoSeleccionada != null
                                                  ? Icons.check_circle
                                                  : Icons.camera_alt,
                                              size: 24,
                                              color: Colors.black87,
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              vm.fotoSeleccionada != null
                                                  ? 'Foto optimizada ✨'
                                                  : 'Adjuntar foto ultra-ligera',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            if (vm.fotoSeleccionada !=
                                                null) ...[
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: vm.removerFoto,
                                                child: Icon(
                                                  Icons.close,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Preview de la foto si existe
                                if (vm.fotoSeleccionada != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        vm.fotoSeleccionada!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '📸 Se optimizará: 512×512px, calidad 60%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Botón Guardar - Fijo al fondo
                Container(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: vm.isLoading || !vm.formularioValido
                          ? null
                          : _guardarGasto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF90CAF9),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: vm.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text(
                              'GUARDAR GASTO ULTRA-LIGERO',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
