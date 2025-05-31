// lib/screens/agregar_gastos/agregar_gastos_screen.dart

import 'package:flutter/material.dart';

class AgregarGastosScreen extends StatefulWidget {
  const AgregarGastosScreen({super.key});

  @override
  State<AgregarGastosScreen> createState() => _AgregarGastosScreenState();
}

class _AgregarGastosScreenState extends State<AgregarGastosScreen>
    with SingleTickerProviderStateMixin {
  String? _categoriaSeleccionada;
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Categoría ExpansionTile que se despliega hacia abajo
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
                            _categoriaSeleccionada ??
                                'Seleccione una categoría',
                            style: TextStyle(
                              color: _categoriaSeleccionada != null
                                  ? Colors.black87
                                  : Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_drop_down_circle,
                              color: Color(0xFF90CAF9)),
                          children: _categorias.map((categoria) {
                            return ListTile(
                              title: Text(categoria,
                                  style: TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w500)),
                              onTap: () async {
                                if (_categoriaSeleccionada != null &&
                                    categoria != _categoriaSeleccionada) {
                                  await _animationController.reverse();
                                  _montoController.clear();
                                  _descripcionController.clear();
                                }
                                setState(() {
                                  _categoriaSeleccionada = categoria;
                                  _animationController.forward();
                                });
                                _expansionController.collapse();
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Campos que aparecen después de seleccionar categoría
                    if (_categoriaSeleccionada != null)
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
                                    color: Colors.black.withValues(alpha: 0.05),
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
                                decoration: const InputDecoration(
                                  labelText: 'Monto',
                                  labelStyle: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87),
                                  hintText: 'S/ 0.00',
                                  hintStyle: TextStyle(color: Colors.black38),
                                  border: InputBorder.none,
                                  prefixText: 'S/ ',
                                  prefixStyle: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Campo Descripción (Visible solo si categoría es "Otro")
                            if (_categoriaSeleccionada == 'Otro') ...[
                              const SizedBox(height: 20),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Descripción',
                                    labelStyle: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    hintText: 'Detalle del gasto...',
                                    hintStyle: TextStyle(color: Colors.black38),
                                    border: InputBorder.none,
                                  ),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],

                            const SizedBox(height: 20),

                            // Botón Adjuntar Foto
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFBBDEFB),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Funcionalidad de cámara pendiente')),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.camera_alt,
                                            size: 24, color: Colors.black87),
                                        SizedBox(width: 12),
                                        Text(
                                          'Adjuntar foto',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Funcionalidad pendiente'),
                        backgroundColor: Color(0xFF90CAF9),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF90CAF9),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'GUARDAR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
