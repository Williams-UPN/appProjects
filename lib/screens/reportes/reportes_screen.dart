// lib/screens/reportes/reportes_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Datos de ejemplo para los gráficos
  final List<FlSpot> _lineChartData = [
    FlSpot(0, 3500),
    FlSpot(1, 4200),
    FlSpot(2, 3800),
    FlSpot(3, 5000),
    FlSpot(4, 4800),
    FlSpot(5, 5200),
    FlSpot(6, 6000),
  ];

  final List<double> _pieChartData = [70, 20, 10]; // Al día, Pendientes, Atrasados
  final List<Color> _pieChartColors = [
    const Color(0xFF10B981), // Verde
    const Color(0xFFF59E0B), // Amarillo
    const Color(0xFFEF4444), // Rojo
  ];
  final List<String> _pieChartLabels = ['Al día', 'Pendientes', 'Atrasados'];
  final List<IconData> _pieChartIcons = [
    Icons.check_circle_outline,
    Icons.access_time,
    Icons.warning_amber_rounded,
  ];

  final List<String> _topZonas = ['Centro', 'Norte', 'Sur'];
  final List<double> _topZonasPercent = [95, 78, 45];
  final List<Color> _topZonasColors = [
    const Color(0xFF10B981), // Verde
    const Color(0xFFF59E0B), // Amarillo
    const Color(0xFFEF4444), // Rojo
  ];

  // Datos para accesos rápidos
  final List<Map<String, dynamic>> _accesosRapidos = [
    {
      'title': 'Riesgos',
      'value': '8',
      'icon': Icons.warning_rounded,
      'color': Color(0xFFEF4444),
    },
    {
      'title': 'Flujo',
      'value': '+5.1k',
      'icon': Icons.attach_money_rounded,
      'color': Color(0xFF10B981),
    },
    {
      'title': 'Mapa',
      'value': '23',
      'icon': Icons.map_rounded,
      'color': Color(0xFF3B82F6),
    },
    {
      'title': 'Ranking',
      'value': 'TOP',
      'icon': Icons.star_rounded,
      'color': Color(0xFFF59E0B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'REPORTES',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        shadowColor: const Color.fromRGBO(0, 0, 0, 0.1),
        centerTitle: true,
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SECCIÓN: RESUMEN FINANCIERO
                _buildSectionHeader('💰 RESUMEN FINANCIERO'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      _buildMainCard(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSecondaryCard(
                              'INGRESOS',
                              'S/15,230',
                              '↑12%',
                              const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSecondaryCard(
                              'GASTOS',
                              'S/2,780',
                              '↓5%',
                              const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // SECCIÓN: ANÁLISIS DE CARTERA
                _buildSectionHeader('📊 ANÁLISIS DE CARTERA'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Gráfico Donut
                            Expanded(
                              flex: 3,
                              child: SizedBox(
                                height: 180,
                                child: PieChart(
                                  PieChartData(
                                    pieTouchData: PieTouchData(
                                      touchCallback: (_, __) {},
                                    ),
                                    borderData: FlBorderData(show: false),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    sections: List.generate(
                                      _pieChartData.length,
                                      (i) {
                                        return PieChartSectionData(
                                          color: _pieChartColors[i],
                                          value: _pieChartData[i] * _animation.value,
                                          title: '${(_pieChartData[i]).toInt()}%',
                                          radius: 80,
                                          titleStyle: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Leyenda
                            Expanded(
                              flex: 2,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  _pieChartData.length,
                                  (i) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _pieChartIcons[i],
                                          color: _pieChartColors[i],
                                          size: 24,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_pieChartData[i].toInt()}% ${_pieChartLabels[i]}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // SECCIÓN: TENDENCIA SEMANAL
                _buildSectionHeader('📈 TENDENCIA SEMANAL'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.withValues(alpha: 0.2),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                const style = TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                );
                                String text;
                                switch (value.toInt()) {
                                  case 0:
                                    text = 'Lu';
                                    break;
                                  case 1:
                                    text = 'Ma';
                                    break;
                                  case 2:
                                    text = 'Mi';
                                    break;
                                  case 3:
                                    text = 'Ju';
                                    break;
                                  case 4:
                                    text = 'Vi';
                                    break;
                                  case 5:
                                    text = 'Sa';
                                    break;
                                  case 6:
                                    text = 'Do';
                                    break;
                                  default:
                                    text = '';
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(text, style: style),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                const style = TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                );
                                String text;
                                if (value == 0) {
                                  text = '0';
                                } else if (value == 3000) {
                                  text = '3K';
                                } else if (value == 6000) {
                                  text = '6K';
                                } else {
                                  return Container();
                                }
                                return SideTitleWidget(
                                  axisSide: meta.axisSide,
                                  child: Text(text, style: style),
                                );
                              },
                            ),
                          ),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: 7000,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _lineChartData.map((spot) {
                              return FlSpot(
                                spot.x,
                                spot.y * _animation.value,
                              );
                            }).toList(),
                            isCurved: true,
                            color: const Color(0xFF3B82F6),
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // SECCIÓN: RENDIMIENTO POR ZONAS
                _buildSectionHeader('🏆 RENDIMIENTO POR ZONAS'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: List.generate(
                        _topZonas.length,
                        (i) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${i + 1}. ${_topZonas[i]}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_topZonasPercent[i].toInt()}%',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: _topZonasColors[i],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (_topZonasPercent[i] / 100) * _animation.value,
                                    minHeight: 12,
                                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(_topZonasColors[i]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // SECCIÓN: ACCESOS RÁPIDOS
                _buildSectionHeader('🔍 ACCESOS RÁPIDOS'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: List.generate(
                        _accesosRapidos.length,
                        (i) => Expanded(
                          child: _buildAccesoRapido(
                            _accesosRapidos[i]['title'],
                            _accesosRapidos[i]['value'],
                            _accesosRapidos[i]['icon'],
                            _accesosRapidos[i]['color'],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Transform.translate(
      offset: Offset(0, 20 - 20 * _animation.value),
      child: Opacity(
        opacity: _animation.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          color: const Color(0xFFF5F5F5),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    return Transform.translate(
      offset: Offset(0, 30 - 30 * _animation.value),
      child: Opacity(
        opacity: _animation.value,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF9F7AEA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ver detalles del día'),
                    backgroundColor: Color(0xFF7C3AED),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'HOY: S/ 12,450',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(
                          Icons.arrow_upward,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '15% vs ayer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryCard(String title, String value, String change, Color color) {
    return Transform.translate(
      offset: Offset(0, 40 - 40 * _animation.value),
      child: Opacity(
        opacity: _animation.value,
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  change,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccesoRapido(String title, String value, IconData icon, Color color) {
    return Transform.translate(
      offset: Offset(0, 60 - 60 * _animation.value),
      child: Opacity(
        opacity: _animation.value,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ver $title'),
                  backgroundColor: color,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}