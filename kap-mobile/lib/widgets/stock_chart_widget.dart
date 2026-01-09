import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StockChartWidget extends StatefulWidget {
  final String ticker;

  const StockChartWidget({super.key, required this.ticker});

  @override
  State<StockChartWidget> createState() => _StockChartWidgetState();
}

class _StockChartWidgetState extends State<StockChartWidget> {
  final ApiService _apiService = ApiService();
  String _selectedTimeframe = '3A'; // Varsayılan 3 Aylık
  List<dynamic> _chartData = [];
  bool _isLoading = true;
  String? _error;

  // Timeframes: 1G (Gün), 1H (Hafta), 1A (Ay), 3A (3 Ay), 1Y (Yıl), 5Y (5 Yıl)
  final List<String> _timeframes = ['1G', '1H', '1A', '3A', '1Y', '5Y'];

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getChartData(widget.ticker, _selectedTimeframe);
      setState(() {
        _chartData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ HATA OLUŞTU: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onTimeframeChanged(String timeframe) {
    if (_selectedTimeframe != timeframe) {
      setState(() {
        _selectedTimeframe = timeframe;
      });
      _loadChartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Timeframes + Price Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeframe Selector
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _timeframes.map((tf) {
                      final isSelected = _selectedTimeframe == tf;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: InkWell(
                          onTap: () => _onTimeframeChanged(tf),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
                            ),
                            child: Text(
                              tf,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Price Info
              if (!_isLoading && _chartData.isNotEmpty)
                _buildPriceInfo(),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Area
          SizedBox(
            height: 200,
            child: _buildChartContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildChartContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Grafik yüklenemedi',
          style: TextStyle(color: Colors.red.shade300, fontSize: 12),
        ),
      );
    }

    if (_chartData.isEmpty) {
      return const Center(child: Text('Veri yok'));
    }

    List<FlSpot> spots = [];
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;

    for (int i = 0; i < _chartData.length; i++) {
      final price = (_chartData[i]['price'] as num).toDouble();
      if (price < minPrice) minPrice = price;
      if (price > maxPrice) maxPrice = price;
      spots.add(FlSpot(i.toDouble(), price));
    }

    if (spots.isEmpty) return const Center(child: Text('Veri yok'));

    final isPositive = spots.last.y >= spots.first.y;
    final lineColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444); // Emerald-500 or Red-500
    
    // Add 2% padding to Y-axis
    final double yPadding = (maxPrice - minPrice) * 0.02;
    minPrice = minPrice - yPadding;
    maxPrice = maxPrice + yPadding;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxPrice - minPrice) / 4, // ~5 lines
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          // Hide Top & Left
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          
          // Right Axis: Price
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == minPrice || value == maxPrice) return const SizedBox.shrink();
                return Text(
                  value.toStringAsFixed(2),
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          
          // Bottom Axis: Date
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (_chartData.length / 4).ceilToDouble(), // Show ~4 labels
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _chartData.length) return const SizedBox.shrink();

                final dateStr = _chartData[index]['date'] as String;
                String label = '';
                try {
                  // API'den gelen format: "yyyy-MM-dd" (saat bilgisi yok)
                  final date = DateTime.parse(dateStr);
                  // Tüm zaman dilimleri için tarih göster (gün/ay)
                  label = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
                } catch (e) {
                  // Parse edilemezse ham string'i göster
                  label = dateStr.length > 5 ? dateStr.substring(5) : dateStr;
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: minPrice, 
        maxY: maxPrice,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2, // Smoother curve
            color: lineColor,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withOpacity(0.25),
                  lineColor.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final index = touchedSpot.x.toInt();
                String dateLabel = '';
                if (index >= 0 && index < _chartData.length) {
                  final dateStr = _chartData[index]['date'] as String;
                  try {
                    final date = DateTime.parse(dateStr);
                    // Tarih formatı: gün/ay/yıl
                    dateLabel = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    // Eğer saat bilgisi varsa (00:00:00 değilse) ekle
                    if (date.hour != 0 || date.minute != 0 || date.second != 0) {
                      dateLabel += ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                    }
                  } catch (e) {
                    dateLabel = dateStr;
                  }
                }
                return LineTooltipItem(
                  '$dateLabel\n₺${touchedSpot.y.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  Widget _buildPriceInfo() {
    final firstPrice = (_chartData.first['price'] as num).toDouble();
    final lastPrice = (_chartData.last['price'] as num).toDouble();
    final change = lastPrice - firstPrice;
    final changePercent = (change / firstPrice) * 100;
    final isPositive = change >= 0;

    // Tarih aralığını hesapla
    String dateRange = '';
    try {
      final firstDateStr = _chartData.first['date'] as String;
      final lastDateStr = _chartData.last['date'] as String;
      final firstDate = DateTime.parse(firstDateStr);
      final lastDate = DateTime.parse(lastDateStr);
      dateRange = '${firstDate.day.toString().padLeft(2, '0')}/${firstDate.month.toString().padLeft(2, '0')} - ${lastDate.day.toString().padLeft(2, '0')}/${lastDate.month.toString().padLeft(2, '0')}';
    } catch (e) {
      dateRange = _selectedTimeframe;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Tarih aralığı
        Text(
          dateRange,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '₺${lastPrice.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 2),
            Text(
              '%${changePercent.abs().toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
