import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import '../config.dart';
class HistoryScreen extends StatefulWidget {
  final String authHeader;

  const HistoryScreen({super.key, required this.authHeader});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  static const String _baseUrl = AppConfig.baseUrl;

  List<dynamic> _allData = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // Hiển thị bao nhiêu điểm gần nhất
  int _displayCount = 30;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/data'),
        headers: {'Authorization': widget.authHeader},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _allData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() { _error = 'Lỗi server: ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Không kết nối được server'; _isLoading = false; });
    }
  }

  // Lấy N bản ghi gần nhất
  List<dynamic> get _recentData {
    if (_allData.length <= _displayCount) return _allData;
    return _allData.sublist(_allData.length - _displayCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A28),
        title: const Text('Lịch sử dữ liệu',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchHistory,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF6366F1),
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.thermostat_rounded), text: 'Nhiệt độ'),
            Tab(icon: Icon(Icons.wb_sunny_rounded), text: 'Ánh sáng'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _error != null
              ? _buildError()
              : _allData.isEmpty
                  ? _buildEmpty()
                  : Column(
                      children: [
                        _buildRangeSelector(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTempTab(),
                              _buildLightTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFF151A28),
      child: Row(
        children: [
          Text('Hiển thị:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(width: 12),
          ...[20, 30, 50, 100].map((n) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _displayCount = n),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _displayCount == n
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF0A0E1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _displayCount == n
                        ? const Color(0xFF6366F1)
                        : Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text('$n',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _displayCount == n ? Colors.white : Colors.white54,
                    )),
              ),
            ),
          )),
          const Spacer(),
          Text('${_recentData.length} bản ghi',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTempTab() {
    final data = _recentData;
    if (data.isEmpty) return _buildEmpty();

    final spots = data.asMap().entries.map((e) {
      final temp = (e.value['temperature'] as num).toDouble();
      return FlSpot(e.key.toDouble(), temp);
    }).toList();

    final temps = spots.map((s) => s.y).toList();
    final minY = (temps.reduce((a, b) => a < b ? a : b) - 2).clamp(0, 100).toDouble();
    final maxY = (temps.reduce((a, b) => a > b ? a : b) + 2).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatRow(temps, '°C', const Color(0xFFFB923C)),
          const SizedBox(height: 20),
          _buildChartCard(
            title: 'Nhiệt độ theo thời gian',
            color: const Color(0xFFFB923C),
            spots: spots,
            minY: minY,
            maxY: maxY,
            unit: '°C',
            dangerLine: 30.0,
          ),
          const SizedBox(height: 16),
          _buildFanStatusList(data),
        ],
      ),
    );
  }

  Widget _buildLightTab() {
    final data = _recentData;
    if (data.isEmpty) return _buildEmpty();

    final spots = data.asMap().entries.map((e) {
      final light = (e.value['lightLevel'] as num).toDouble();
      return FlSpot(e.key.toDouble(), light);
    }).toList();

    final lights = spots.map((s) => s.y).toList();
    final minY = (lights.reduce((a, b) => a < b ? a : b) - 100).clamp(0, 9999).toDouble();
    final maxY = (lights.reduce((a, b) => a > b ? a : b) + 100).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatRow(lights, 'lux', const Color(0xFFFBBF24)),
          const SizedBox(height: 20),
          _buildChartCard(
            title: 'Ánh sáng theo thời gian',
            color: const Color(0xFFFBBF24),
            spots: spots,
            minY: minY,
            maxY: maxY,
            unit: 'lux',
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(List<double> values, String unit, Color color) {
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        _buildStatCard('Trung bình', '${avg.toStringAsFixed(1)}$unit', color),
        const SizedBox(width: 12),
        _buildStatCard('Thấp nhất', '${min.toStringAsFixed(1)}$unit',
            Colors.blue.shade300),
        const SizedBox(width: 12),
        _buildStatCard('Cao nhất', '${max.toStringAsFixed(1)}$unit',
            const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF151A28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required Color color,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required String unit,
    double? dangerLine,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              if (dangerLine != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Ngưỡng ${dangerLine.toStringAsFixed(0)}$unit',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.w600)),
                ),
              ]
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                extraLinesData: dangerLine != null
                    ? ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: dangerLine,
                          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                        ),
                      ])
                    : null,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: FlDotData(show: spots.length <= 20),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.08),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) =>
                      LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} $unit',
                        TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      )).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFanStatusList(List<dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trạng thái thiết bị gần nhất',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...data.reversed.take(8).map((item) {
            final fan = item['fanStatus'] == 1;
            final led = item['ledStatus'] == 1;
            final temp = (item['temperature'] as num).toDouble();
            final ts = item['timestamp'] != null
                ? _formatTime(item['timestamp'].toString())
                : '--:--';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(ts,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                          fontFamily: 'monospace')),
                  const SizedBox(width: 12),
                  Text('${temp.toStringAsFixed(1)}°C',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _statusPill('Quạt', fan, const Color(0xFF22D3EE)),
                  const SizedBox(width: 8),
                  _statusPill('Đèn', led, const Color(0xFFFBBF24)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statusPill(String label, bool isOn, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOn ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text('$label ${isOn ? "ON" : "OFF"}',
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isOn ? color : Colors.white38)),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    } catch (_) {
      return '--:--';
    }
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchHistory,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1)),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, color: Colors.white24, size: 48),
          SizedBox(height: 16),
          Text('Chưa có dữ liệu', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}
