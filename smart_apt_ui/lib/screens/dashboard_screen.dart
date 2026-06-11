import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'login_screen.dart';
import 'settings_screen.dart'; // Import màn hình Settings
import 'history_screen.dart';
import '../config.dart';

class DashboardScreen extends StatefulWidget {
  final String authHeader;
  final String username;
  final String role; // Khai báo role

  const DashboardScreen({
    super.key,
    required this.authHeader,
    required this.username,
    required this.role, // Bắt buộc truyền role
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  String latestTemp = "--";
  String latestLight = "--";
  String latestHumi = "--";
  String latestDist = "--";
  String latestWind = "--";
  int fanStatus = 0;
  List<int> ledStates = [0, 0, 0, 0, 0];
  bool isFanManual = false;
  bool isLedManual = false;
  bool isFanLocked = false;
  bool isLedLocked = false;
  bool isDeviceOnline = false;
  DateTime? lastDataReceived;

  Timer? timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    fetchLatestData();
    fetchDeviceStatus();
    timer = Timer.periodic(const Duration(seconds: 2), (Timer t) {
      fetchLatestData();
      fetchDeviceStatus();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _logout() {
    timer?.cancel();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, anim, secondAnim) => const LoginScreen(),
        transitionsBuilder: (ctx, anim, secondAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  bool get isDataStale {
    if (lastDataReceived == null) return true;
    return DateTime.now().difference(lastDataReceived!).inSeconds > 10;
  }

  Future<void> fetchLatestData() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/data'),
        headers: {'Authorization': widget.authHeader},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          var newestReading = data.last;
          setState(() {
            // Nhiệt độ trung bình 5 phòng (hoặc temp0)
            latestTemp = (newestReading['temp0'] ?? newestReading['temperature'])
                .toStringAsFixed(1);
            // Độ ẩm trung bình (humi0)
			final h0 = (newestReading['humi0'] as num?)?.toDouble() ?? 0.0;
            final h1 = (newestReading['humi1'] as num?)?.toDouble() ?? 0.0;
            final h2 = (newestReading['humi2'] as num?)?.toDouble() ?? 0.0;
            final h3 = (newestReading['humi3'] as num?)?.toDouble() ?? 0.0;
            final h4 = (newestReading['humi4'] as num?)?.toDouble() ?? 0.0;

            // Nếu h0 = 0 (mất dữ liệu) thì giữ nguyên "--", nếu có thì tính trung bình
            if (newestReading['humi0'] != null) {
              final avgHumi = (h0 + h1 + h2 + h3 + h4) / 5;
              latestHumi = avgHumi.toStringAsFixed(0);
            } else {
              latestHumi = "--";
            }
            latestLight = newestReading['lightLevel'].toString();
            // Khoảng cách & gió mới
            final d = newestReading['distance'];
            latestDist = d != null ? d.toStringAsFixed(0) : "--";
            final w = newestReading['wind'];
            latestWind = w != null ? w.toString() : "--";

            if (!isFanLocked) {
              fanStatus = newestReading['fanStatus'];
              isFanManual = newestReading['fanManual'] ?? false;
            }
            if (!isLedLocked) {
              // Đọc trạng thái 5 LED riêng (led0-led4), fallback ledStatus
              for (int i = 0; i < 5; i++) {
                final v = newestReading['led$i'];
                if (v != null) ledStates[i] = v;
              }
              isLedManual = newestReading['ledManual'] ?? false;
            }
            lastDataReceived = DateTime.now();
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> fetchDeviceStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/status'),
        headers: {'Authorization': widget.authHeader},
      );
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          isDeviceOnline = data['online'] == true;
        });
      }
    } catch (e) {
      setState(() => isDeviceOnline = false);
    }
  }

  Future<void> toggleDevice(String device, bool isOn) async {
    int status = isOn ? 1 : 0;
    setState(() {
      // Chỉ còn dùng cho quạt (LED đã chuyển sang toggleLed riêng)
      fanStatus = status;
      isFanManual = true;
      isFanLocked = true;
    });

    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/control/$device?status=$status'),
        headers: {'Authorization': widget.authHeader},
      );
    } catch (e) {
      // ignore
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          if (device == 'fan') isFanLocked = false;
          if (device == 'led') isLedLocked = false;
        });
      }
    });
  }

  // Điều khiển từng LED riêng (index 0-4)
  Future<void> toggleLed(int index, bool isOn) async {
    int status = isOn ? 1 : 0;
    setState(() {
      ledStates[index] = status;
      isLedManual = true;
      isLedLocked = true;
    });
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/control/led/$index?status=$status'),
        headers: {'Authorization': widget.authHeader},
      );
    } catch (e) {
      // ignore
    }
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => isLedLocked = false);
    });
  }

  Future<void> setAutoMode(String device) async {
    setState(() {
      if (device == 'fan') {
        isFanManual = false;
        isFanLocked = true;
      } else {
        isLedManual = false;
        isLedLocked = true;
      }
    });
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/control/$device?status=2'),
        headers: {'Authorization': widget.authHeader},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.autorenew, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text('${device.toUpperCase()} switched to Auto Mode'),
          ]),
          backgroundColor: const Color(0xFF6366F1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // ignore
    }
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (device == 'fan') isFanLocked = false;
          if (device == 'led') isLedLocked = false;
        });
      }
    });
  }

  Future<void> muteAlarm() async {
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/control/buzzer?status=0'),
        headers: {'Authorization': widget.authHeader},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(children: [
            Icon(Icons.notifications_off, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text('Alarm muted for 5 minutes!'),
          ]),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // ignore
    }
  }

  String _lastUpdatedText() {
    if (lastDataReceived == null) return "Never";
    final secs = DateTime.now().difference(lastDataReceived!).inSeconds;
    if (secs < 5) return "Just now";
    if (secs < 60) return "${secs}s ago";
    return "${(secs / 60).floor()}m ago";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildConnectionBanner(),
              const SizedBox(height: 24),
              _buildSensorRow(),
              const SizedBox(height: 32),
              _buildSectionTitle("Device Controls"),
              const SizedBox(height: 12),
              _buildDeviceCard(
                title: "Living Room Fan",
                subtitle: fanStatus == 1 ? "Running" : "Idle",
                icon: Icons.air,
                isOn: fanStatus == 1,
                isManual: isFanManual,
                accentColor: const Color(0xFF22D3EE),
                onToggle: (v) => toggleDevice('fan', v),
                onAuto: () => setAutoMode('fan'),
              ),
              const SizedBox(height: 16),
              _buildLedGrid(),
              const SizedBox(height: 24),

              // CẨN THẬN: Chỉ hiển thị nút MUTE nếu KHÔNG phải là Guest
              if (!widget.role.contains('GUEST'))
                ElevatedButton.icon(
                  onPressed: muteAlarm,
                  icon: const Icon(Icons.volume_off_rounded),
                  label: const Text(
                    "MUTE EMERGENCY ALARM",
                    style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 1),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Xin chào, ${widget.username}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "Updated ${_lastUpdatedText()}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            // NÚT LỊCH SỬ (Ai cũng xem được)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(authHeader: widget.authHeader),
                ),
              ),
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: 'Lịch sử dữ liệu',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF151A28),
                foregroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),

            // NÚT CÀI ĐẶT (Chỉ Admin mới thấy)
            if (widget.role.contains('ADMIN'))
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(authHeader: widget.authHeader),
                    ),
                  ),
                  icon: const Icon(Icons.settings_rounded),
                  tooltip: 'Cài đặt hệ thống',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF151A28),
                    foregroundColor: Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),

            // NÚT LÀM MỚI
            IconButton(
              onPressed: () {
                fetchLatestData();
                fetchDeviceStatus();
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Làm mới',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF151A28),
                foregroundColor: Colors.white.withValues(alpha: 0.7),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 8),

            // NÚT ĐĂNG XUẤT
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Đăng xuất',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionBanner() {
    final isStale = isDataStale;
    final showOnline = isDeviceOnline && !isStale;

    final color = showOnline
        ? const Color(0xFF10B981)
        : (isStale ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    final label = showOnline
        ? "ESP32 Connected"
        : (isStale ? "Stale Data — Check Device" : "ESP32 Offline");
    final detail = showOnline
        ? "Receiving live sensor data"
        : (isStale
        ? "No new readings for >10 seconds"
        : "Device is unreachable");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: showOnline
                      ? [
                    BoxShadow(
                      color: color.withValues(
                          alpha: 0.6 + 0.4 * _pulseController.value),
                      blurRadius: 12 + 8 * _pulseController.value,
                      spreadRadius: 2 + 2 * _pulseController.value,
                    ),
                  ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: color)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorRow() {
    return Column(
      children: [
        // Hàng 1: Nhiệt độ + Độ ẩm
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                label: "Temperature",
                value: latestTemp,
                unit: "°C",
                icon: Icons.thermostat_rounded,
                accent: const Color(0xFFFB923C),
                isHighlight: double.tryParse(latestTemp) != null &&
                    double.parse(latestTemp) > 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSensorCard(
                label: "Humidity",
                value: latestHumi,
                unit: "%",
                icon: Icons.water_drop_rounded,
                accent: const Color(0xFF38BDF8),
                isHighlight: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Hàng 2: Ánh sáng + Khoảng cách + Gió
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                label: "Light",
                value: latestLight,
                unit: "lux",
                icon: Icons.wb_sunny_rounded,
                accent: const Color(0xFFFBBF24),
                isHighlight: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                label: "Distance",
                value: latestDist,
                unit: "cm",
                icon: Icons.straighten_rounded,
                accent: const Color(0xFFA78BFA),
                isHighlight: double.tryParse(latestDist) != null &&
                    double.parse(latestDist) < 15,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                label: "Wind",
                value: latestWind,
                unit: "%",
                icon: Icons.air_rounded,
                accent: const Color(0xFF34D399),
                isHighlight: false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color accent,
    required bool isHighlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF151A28), Color(0xFF1A2030)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight
              ? accent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: isHighlight
            ? [BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -5)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(value,
                      key: ValueKey(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: -1)),
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(unit,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3));
  }

  Widget _buildDeviceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isOn,
    required bool isManual,
    required Color accentColor,
    required ValueChanged<bool> onToggle,
    required VoidCallback onAuto,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOn
              ? accentColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: isOn
            ? [BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: -5)]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOn
                        ? accentColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: isOn ? accentColor : Colors.white.withValues(alpha: 0.4),
                      size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          _buildModePill(isManual),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5))),
                    ],
                  ),
                ),
                Switch(
                  value: isOn,
                  // CẨN THẬN: Không cho Guest click đổi trạng thái Switch
                  onChanged: widget.role.contains('GUEST') ? null : onToggle,
                  activeThumbColor: Colors.white,
                  activeTrackColor: accentColor,
                  inactiveThumbColor: Colors.white.withValues(alpha: 0.6),
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          // CẨN THẬN: Ẩn nút gạt về Auto Mode đối với Guest
          if (!widget.role.contains('GUEST'))
            InkWell(
              onTap: onAuto,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.autorenew_rounded,
                        color: Color(0xFF6366F1), size: 18),
                    SizedBox(width: 8),
                    Text("Switch to Auto Mode",
                        style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLedGrid() {
    final isGuest = widget.role.contains('GUEST');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFFFBBF24), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("5 đèn LED",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              _buildModePill(isLedManual),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(5, (i) {
            final on = ledStates[i] == 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: on
                          ? const Color(0xFFFBBF24).withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.lightbulb,
                        size: 16,
                        color: on ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text("LED ${i + 1}",
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  Text(on ? "ON" : "OFF",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: on ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.4))),
                  const SizedBox(width: 8),
                  Switch(
                    value: on,
                    onChanged: isGuest ? null : (v) => toggleLed(i, v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFFFBBF24),
                    inactiveThumbColor: Colors.white.withValues(alpha: 0.6),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                  ),
                ],
              ),
            );
          }),
          if (!isGuest) ...[
            Container(
                height: 1,
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.white.withValues(alpha: 0.05)),
            InkWell(
              onTap: () => setAutoMode('led'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.autorenew_rounded, color: Color(0xFF6366F1), size: 18),
                    SizedBox(width: 8),
                    Text("Chuyển tất cả về Auto",
                        style: TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w500,
                            fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModePill(bool isManual) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isManual
            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
            : const Color(0xFF10B981).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isManual ? "MANUAL" : "AUTO",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isManual ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}