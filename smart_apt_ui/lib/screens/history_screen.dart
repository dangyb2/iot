import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';
import '../config.dart';

class HistoryScreen extends StatefulWidget {
  final String authHeader;

  const HistoryScreen({super.key, required this.authHeader});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const String _baseUrl = AppConfig.baseUrl;

  Map<String, dynamic> _latest = {};
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  String _selectedGroup = 'main'; // 'main' hoặc 'humi'

  // Ngưỡng lấy từ backend
  double _tempOn = 30.0;
  double _tempDanger = 35.0;
  double _humiOn = 80.0;
  double _humiOff = 72.0;
  double _lightOn = 1000.0;
  double _lightOff = 1200.0;

  @override
  void initState() {
    super.initState();
    _fetchConfig();
    _fetchLatest();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchLatest();
      _fetchConfig();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/config'),
        headers: {'Authorization': widget.authHeader},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final cfg = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _tempOn = (cfg['tempOn'] as num?)?.toDouble() ?? 30.0;
          _tempDanger = (cfg['tempDanger'] as num?)?.toDouble() ?? 35.0;
          _humiOn = (cfg['humiOn'] as num?)?.toDouble() ?? 80.0;
          _humiOff = (cfg['humiOff'] as num?)?.toDouble() ?? 72.0;
          _lightOn = (cfg['lightOn'] as num?)?.toDouble() ?? 1000.0;
          _lightOff = (cfg['lightOff'] as num?)?.toDouble() ?? 1200.0;
        });
      }
    } catch (_) {/* giữ giá trị cũ */}
  }

  Future<void> _fetchLatest() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/data'),
        headers: {'Authorization': widget.authHeader},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final List<dynamic> all = jsonDecode(response.body);
        if (all.isNotEmpty) {
          setState(() {
            _latest = all.last as Map<String, dynamic>;
            _isLoading = false;
            _error = null;
          });
        }
      }
    } catch (e) {
      if (_isLoading) {
        setState(() {
          _error = 'Không kết nối được server';
          _isLoading = false;
        });
      }
    }
  }

  double _val(String key) {
    final v = _latest[key];
    return v == null ? 0 : (v as num).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A28),
        title: const Text('Giám sát realtime',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                _fetchLatest();
                _fetchConfig();
              }),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2 TAB
          Row(
            children: [
              _buildTab('main', 'Cảm biến chính', Icons.dashboard_rounded),
              const SizedBox(width: 8),
              _buildTab('humi', '5 độ ẩm', Icons.water_drop_rounded),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedGroup == 'main') _buildMainChart(),
          if (_selectedGroup == 'humi') _buildHumiChart(),
          const SizedBox(height: 16),
          Text('Cập nhật mỗi 2 giây · Ngưỡng đồng bộ từ Settings',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildTab(String key, String label, IconData icon) {
    final isSelected = _selectedGroup == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGroup = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF151A28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ============= TAB 1: 4 CẢM BIẾN CHÍNH (Nhiệt + Sáng + Gió + Gần) =============
  Widget _buildMainChart() {
    final tempVal = _val('temp0');
    // Backend lưu là 'lightLevel', fallback 'light' để tương thích
    final lightVal = _latest['lightLevel'] != null
        ? (_latest['lightLevel'] as num).toDouble()
        : _val('light');
    final windVal = _val('wind');
    final distVal = _val('distance');

    // Chuẩn hoá thông minh: vượt ngưỡng nguy hiểm → chạm 80% (vạch đỏ)
    final tempPct = _tempDanger > 0
        ? (tempVal / _tempDanger * 80).clamp(0, 100).toDouble() : 0.0;
    final lightPct = _lightOff > 0
        ? (lightVal / _lightOff * 80).clamp(0, 100).toDouble() : 0.0;
    final windPctClamped = (windVal / 70 * 80).clamp(0, 100).toDouble();
    final distPct = ((400 - distVal) / (400 - 15) * 80).clamp(0, 100).toDouble();

    // Giá trị thật để hiện trên đầu mỗi thanh
    final realLabels = [
      '${tempVal.toStringAsFixed(1)}°C',
      '${lightVal.toInt()}',
      '${windVal.toInt()}%',
      '${distVal.toInt()}cm',
    ];

    // Hàm trộn 2 màu theo tỉ lệ 0..1
    Color blend(Color cool, Color hot, double t) {
      return Color.lerp(cool, hot, t.clamp(0.0, 1.0))!;
    }

    // Màu CHỦ ĐẠO của thanh tính theo NGƯỠNG từ Settings (không phải hardcode)
    // → Khi user đổi ngưỡng, dải màu cũng thay đổi theo
    final tempMain = blend(
      const Color(0xFF3B82F6), // ≤ tempOff: xanh dương (mát)
      const Color(0xFFEF4444), // ≥ tempDanger: đỏ (nguy hiểm)
      (_tempDanger - 27.0).abs() < 0.01
          ? 0.5
          : (tempVal - 27.0) / (_tempDanger - 27.0),
    );
    final lightMain = blend(
      const Color(0xFF312E81), // ≤ lightOn: tím đen (tối)
      const Color(0xFFFEF08A), // ≥ lightOff: vàng (sáng)
      (_lightOff - _lightOn).abs() < 0.01
          ? 0.5
          : (lightVal - _lightOn) / (_lightOff - _lightOn),
    );
    final windMain = blend(
      const Color(0xFF67E8F9), // 0%: xanh nhạt (lặng)
      const Color(0xFFEF4444), // 100%: đỏ (bão)
      windVal / 100,
    );
    final distMain = blend(
      const Color(0xFF22C55E), // ≥50cm: xanh lá (an toàn)
      const Color(0xFFEF4444), // ≤15cm: đỏ (có người)
      (50 - distVal.clamp(0, 50)) / 35,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF151A28),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _buildStatRow('Nhiệt độ', tempVal.toStringAsFixed(1), '°C',
                  const Color(0xFFFB923C), tempVal > _tempDanger),
              const Divider(color: Color(0xFF1E2937)),
              _buildStatRow('Ánh sáng', '${lightVal.toInt()}', 'ADC',
                  const Color(0xFFFBBF24), lightVal > _lightOff),
              const Divider(color: Color(0xFF1E2937)),
              _buildStatRow('Sức gió', '${windVal.toInt()}', '%',
                  const Color(0xFF34D399), windVal > 70),
              const Divider(color: Color(0xFF1E2937)),
              _buildStatRow('Khoảng cách', '${distVal.toInt()}', 'cm',
                  const Color(0xFFA78BFA), distVal < 15 && distVal > 0),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildBarChartCard(
          title: 'So sánh 4 cảm biến (% và giá trị thật)',
          unit: '%',
          values: [tempPct, lightPct, windPctClamped, distPct],
          labels: ['Nhiệt', 'Sáng', 'Gió', 'Gần'],
          realValueLabels: realLabels,
          maxY: 100,
          threshold1: 50,
          threshold1Label: 'Trung bình (50%)',
          threshold1Color: const Color(0xFFFBBF24),
          threshold2: 80,
          threshold2Label: 'Cao (80%)',
          threshold2Color: const Color(0xFFEF4444),
          // Mỗi thanh dùng 1 màu chính (gradient nhẹ nhạt-đậm cho có chiều sâu)
          barGradients: [
            [tempMain.withValues(alpha: 0.7), tempMain],
            [lightMain.withValues(alpha: 0.7), lightMain],
            [windMain.withValues(alpha: 0.7), windMain],
            [distMain.withValues(alpha: 0.7), distMain],
          ],
          getBarColor: (v) => const Color(0xFF6366F1),
        ),
      ],
    );
  }

  // ============= TAB 2: 5 ĐỘ ẨM =============
  Widget _buildHumiChart() {
    final humis = [_val('humi0'), _val('humi1'), _val('humi2'), _val('humi3'), _val('humi4')];

    Color blend(Color cool, Color hot, double t) {
      return Color.lerp(cool, hot, t.clamp(0.0, 1.0))!;
    }

    // Mỗi thanh đổi màu theo giá trị độ ẩm so với ngưỡng từ Settings
    // ≤ humiOff: xanh nhạt (khô/khô vừa)
    // ≥ humiOn: đỏ (ẩm cao, bật quạt)
    final List<List<Color>> humiGradients = humis.map((v) {
      final t = (_humiOn - _humiOff).abs() < 0.01
          ? 0.5
          : (v - _humiOff) / (_humiOn - _humiOff);
      final mainColor = blend(
        const Color(0xFF38BDF8), // xanh nhạt: ẩm thấp
        const Color(0xFFEF4444), // đỏ: ẩm cao
        t,
      );
      return [mainColor.withValues(alpha: 0.7), mainColor];
    }).toList();

    return _buildBarChartCard(
      title: 'Độ ẩm 5 cảm biến',
      unit: '%',
      values: humis,
      labels: ['CB 1', 'CB 2', 'CB 3', 'CB 4', 'CB 5'],
      maxY: 100,
      threshold1: _humiOff,
      threshold1Label: 'Tắt quạt (${_humiOff.toStringAsFixed(0)}%)',
      threshold1Color: const Color(0xFFFBBF24),
      threshold2: _humiOn,
      threshold2Label: 'Bật quạt (${_humiOn.toStringAsFixed(0)}%)',
      threshold2Color: const Color(0xFFEF4444),
      barGradients: humiGradients,
      getBarColor: (v) => const Color(0xFF38BDF8),
    );
  }

  Widget _buildStatRow(String label, String value, String unit, Color color, bool isDanger) {
    IconData icon;
    if (label == 'Ánh sáng') {
      icon = Icons.wb_sunny_rounded;
    } else if (label == 'Sức gió') {
      icon = Icons.air_rounded;
    } else if (label == 'Nhiệt độ') {
      icon = Icons.thermostat_rounded;
    } else {
      icon = Icons.straighten_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDanger ? const Color(0xFFEF4444) : color)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(unit,
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartCard({
    required String title,
    required String unit,
    required List<double> values,
    required List<String> labels,
    List<String>? realValueLabels,
    List<List<Color>>? barGradients, // Mỗi thanh có 1 gradient riêng [colorTop, colorBottom]
    required double maxY,
    required double threshold1,
    required String threshold1Label,
    required Color threshold1Color,
    required double threshold2,
    required String threshold2Label,
    required Color threshold2Color,
    required Color Function(double) getBarColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _legendDot(threshold1Color, threshold1Label),
              _legendDot(threshold2Color, threshold2Label),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: Stack(
              children: [
                BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E2937),
                    getTooltipItem: (group, _, rod, __) {
                      return BarTooltipItem(
                        '${labels[group.x]}\n${rod.toY.toStringAsFixed(1)} $unit',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 5,
                      getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[i],
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 5,
                  getDrawingHorizontalLine: (v) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(values.length, (i) {
                  final v = values[i];
                  final color = getBarColor(v);
                  final hasGradient = barGradients != null && i < barGradients.length;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: v,
                        color: hasGradient ? null : color,
                        gradient: hasGradient
                            ? LinearGradient(
                                colors: barGradients[i],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                    ],
                  );
                }),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: threshold1,
                      color: threshold1Color,
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                    ),
                    HorizontalLine(
                      y: threshold2,
                      color: threshold2Color,
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
              ),
              duration: const Duration(milliseconds: 400),
            ),
                // Overlay: label giá trị thật trên đầu mỗi thanh
                if (realValueLabels != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 40, right: 8, bottom: 40),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final chartHeight = constraints.maxHeight;
                        return Stack(
                          children: List.generate(values.length, (i) {
                            final barTopY = chartHeight * (1 - values[i] / maxY);
                            final widthPerBar = constraints.maxWidth / values.length;
                            return Positioned(
                              left: i * widthPerBar,
                              top: (barTopY - 22).clamp(0, chartHeight - 18).toDouble(),
                              width: widthPerBar,
                              child: Text(
                                realValueLabels[i],
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(1)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
