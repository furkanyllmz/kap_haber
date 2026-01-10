import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StockChartWidget extends StatefulWidget {
  final String ticker;
  final Function(double changePercent, String period)? onPeriodChanged;
  final String defaultPeriod;
  final double? currentPrice; // Current price from Prices API

  const StockChartWidget({
    super.key, 
    required this.ticker,
    this.onPeriodChanged,
    this.defaultPeriod = '1G',
    this.currentPrice,
  });

  @override
  State<StockChartWidget> createState() => _StockChartWidgetState();
}

class _StockChartWidgetState extends State<StockChartWidget> {
  final ApiService _apiService = ApiService();
  late String _selectedTimeframe;
  List<dynamic> _chartData = [];
  bool _isLoading = true;
  String? _error;

  // Timeframes: 1G (Gün), 1H (Hafta), 1A (Ay), 3A (3 Ay), 1Y (Yıl), 5Y (5 Yıl)
  final List<String> _timeframes = ['1G', '1H', '1A', '3A', '1Y', '5Y'];

  @override
  void initState() {
    super.initState();
    _selectedTimeframe = widget.defaultPeriod;
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _apiService.getChartData(widget.ticker, _selectedTimeframe);
      if (mounted) {
        setState(() {
          _chartData = data;
          _isLoading = false;
        });
        _notifyPeriodChanged();
      }
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

  void _notifyPeriodChanged() {
    if (widget.onPeriodChanged != null && _chartData.isNotEmpty) {
      final firstPrice = (_chartData.first['price'] as num).toDouble();
      // For non-1G periods, use currentPrice from parent (Prices API) if available
      // For 1G, parent will use DailyChangePercent from Prices API directly
      final lastPrice = widget.currentPrice ?? (_chartData.last['price'] as num).toDouble();
      final changePercent = ((lastPrice - firstPrice) / firstPrice) * 100;
      widget.onPeriodChanged!(changePercent, _selectedTimeframe);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeframe Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _timeframes.map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () => _onTimeframeChanged(tf),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? (isDark ? Colors.white : Colors.white) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      tf,
                      style: TextStyle(
                        color: isSelected 
                            ? const Color(0xFF002B3A) 
                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 16),

          // Chart Area
          SizedBox(
            height: 180,
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
    final lineColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    
    // Add 2% padding to Y-axis
    final double yPadding = (maxPrice - minPrice) * 0.02;
    minPrice = minPrice - yPadding;
    maxPrice = maxPrice + yPadding;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxPrice - minPrice) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (_chartData.length / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _chartData.length) return const SizedBox.shrink();

                final dateStr = _chartData[index]['date'] as String;
                String label = '';
                try {
                  final date = DateTime.parse(dateStr);
                  if (_selectedTimeframe == '1G') {
                    label = '${date.hour.toString().padLeft(2, '0')}:00';
                  } else {
                    label = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
                  }
                } catch (e) {
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
            curveSmoothness: 0.2,
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
                  lineColor.withValues(alpha: 0.25),
                  lineColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueGrey.withValues(alpha: 0.9),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((LineBarSpot touchedSpot) {
                final index = touchedSpot.x.toInt();
                String dateLabel = '';
                if (index >= 0 && index < _chartData.length) {
                  final dateStr = _chartData[index]['date'] as String;
                  try {
                    final date = DateTime.parse(dateStr);
                    dateLabel = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                    if (date.hour != 0 || date.minute != 0) {
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
}
