import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
class SettingsScreen extends StatefulWidget {
  final String authHeader;

  const SettingsScreen({super.key, required this.authHeader});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _baseUrl = AppConfig.baseUrl;

  // Controllers cho từng ngưỡng
  final _tempOnCtrl    = TextEditingController(text: '30');
  final _tempOffCtrl   = TextEditingController(text: '27');
  final _tempDangerCtrl = TextEditingController(text: '35');
  final _lightOnCtrl   = TextEditingController(text: '1000');
  final _lightOffCtrl  = TextEditingController(text: '1200');

  bool _isSaving = false;

  @override
  void dispose() {
    _tempOnCtrl.dispose();
    _tempOffCtrl.dispose();
    _tempDangerCtrl.dispose();
    _lightOnCtrl.dispose();
    _lightOffCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfig() async {
    // Validate
    final tempOn    = double.tryParse(_tempOnCtrl.text);
    final tempOff   = double.tryParse(_tempOffCtrl.text);
    final tempDanger = double.tryParse(_tempDangerCtrl.text);
    final lightOn   = int.tryParse(_lightOnCtrl.text);
    final lightOff  = int.tryParse(_lightOffCtrl.text);

    if ([tempOn, tempOff, tempDanger].any((v) => v == null) ||
        [lightOn, lightOff].any((v) => v == null)) {
      _showSnack('Vui lòng nhập số hợp lệ', isError: true);
      return;
    }
    if (tempOff! >= tempOn!) {
      _showSnack('Ngưỡng TẮT quạt phải nhỏ hơn ngưỡng BẬT', isError: true);
      return;
    }
    if (lightOn! >= lightOff!) {
      _showSnack('Ngưỡng tối phải nhỏ hơn ngưỡng sáng', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final body = jsonEncode({
        'tempOn':     tempOn,
        'tempOff':    tempOff,
        'tempDanger': tempDanger,
        'lightOn':    lightOn,
        'lightOff':   lightOff,
      });

      final response = await http.post(
        Uri.parse('$_baseUrl/api/config'),
        headers: {
          'Authorization': widget.authHeader,
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showSnack('Đã gửi cấu hình xuống ESP32!');
      } else {
        _showSnack('Lỗi server: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnack('Không kết nối được server', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151A28),
        title: const Text(
          'Cấu hình hệ thống',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoBanner(),
            const SizedBox(height: 24),
            _buildSectionCard(
              title: 'Điều khiển Quạt',
              icon: Icons.air,
              color: const Color(0xFF22D3EE),
              children: [
                _buildThresholdField(
                  controller: _tempOnCtrl,
                  label: 'Nhiệt độ BẬT quạt (°C)',
                  hint: 'Ví dụ: 30',
                  icon: Icons.thermostat_rounded,
                ),
                const SizedBox(height: 16),
                _buildThresholdField(
                  controller: _tempOffCtrl,
                  label: 'Nhiệt độ TẮT quạt (°C)',
                  hint: 'Ví dụ: 27',
                  icon: Icons.thermostat_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Điều khiển Đèn LED',
              icon: Icons.lightbulb_outline,
              color: const Color(0xFFFBBF24),
              children: [
                _buildThresholdField(
                  controller: _lightOnCtrl,
                  label: 'Ngưỡng tối — BẬT đèn (ADC)',
                  hint: 'Ví dụ: 1000',
                  icon: Icons.wb_sunny_rounded,
                ),
                const SizedBox(height: 16),
                _buildThresholdField(
                  controller: _lightOffCtrl,
                  label: 'Ngưỡng sáng — TẮT đèn (ADC)',
                  hint: 'Ví dụ: 1200',
                  icon: Icons.wb_sunny_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Cảnh báo nhiệt độ',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEF4444),
              children: [
                _buildThresholdField(
                  controller: _tempDangerCtrl,
                  label: 'Nhiệt độ NGUY HIỂM — kích còi (°C)',
                  hint: 'Ví dụ: 35',
                  icon: Icons.crisis_alert_rounded,
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveConfig,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSaving ? 'Đang gửi...' : 'Gửi cấu hình xuống ESP32',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded,
              color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chỉ Admin mới truy cập được màn hình này.\nThay đổi sẽ được gửi trực tiếp xuống ESP32 qua MQTT.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThresholdField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(icon, color: Colors.white.withValues(alpha: 0.4), size: 18),
              hintText: hint,
              hintStyle:
                  TextStyle(color: Colors.white.withValues(alpha: 0.25)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
