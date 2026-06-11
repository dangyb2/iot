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
  final _tempOffCtrl   = TextEditingController(text: '27.0');
  final _tempDangerCtrl = TextEditingController(text: '36.0');
  final _humiOnCtrl    = TextEditingController(text: '80');
  final _humiOffCtrl   = TextEditingController(text: '72.0');
  final _lightOnCtrl   = TextEditingController(text: '1000');
  final _lightOffCtrl  = TextEditingController(text: '1200');

  bool _isSaving = false;

  @override
  void dispose() {
    _tempOnCtrl.dispose();
    _tempOffCtrl.dispose();
    _tempDangerCtrl.dispose();
    _humiOnCtrl.dispose();
    _humiOffCtrl.dispose();
    _lightOnCtrl.dispose();
    _lightOffCtrl.dispose();
    super.dispose();
  }

  // ===== HÀM TỰ ĐỘNG TÍNH TOÁN % =====
  void _onTempChanged(String val) {
    final temp = double.tryParse(val);
    if (temp != null) {
      setState(() {
        _tempOffCtrl.text = (temp * 0.90).toStringAsFixed(1);   // 90%
        _tempDangerCtrl.text = (temp * 1.20).toStringAsFixed(1); // 120%
      });
    } else {
      setState(() {
        _tempOffCtrl.text = '';
        _tempDangerCtrl.text = '';
      });
    }
  }

  void _onLightChanged(String val) {
    final light = double.tryParse(val);
    if (light != null) {
      setState(() {
        _lightOffCtrl.text = (light * 1.20).toInt().toString(); // 120%
      });
    } else {
      setState(() {
        _lightOffCtrl.text = '';
      });
    }
  }

  void _onHumiChanged(String val) {
    final humi = double.tryParse(val);
    if (humi != null) {
      setState(() {
        _humiOffCtrl.text = (humi * 0.90).toStringAsFixed(1); // 90%
      });
    } else {
      setState(() {
        _humiOffCtrl.text = '';
      });
    }
  }

  Future<void> _saveConfig() async {
    // Validate 3 ngưỡng gốc
    final tempOn  = double.tryParse(_tempOnCtrl.text);
    final humiOn  = double.tryParse(_humiOnCtrl.text);
    final lightOn = int.tryParse(_lightOnCtrl.text);

    if (tempOn == null || humiOn == null || lightOn == null) {
      _showSnack('Vui lòng nhập số hợp lệ cho Ngưỡng Gốc', isError: true);
      return;
    }

    // Lấy giá trị đã tự tính để gửi xuống Server
    final tempOff    = double.parse(_tempOffCtrl.text);
    final tempDanger = double.parse(_tempDangerCtrl.text);
    final humiOff    = double.parse(_humiOffCtrl.text);
    final lightOff   = int.parse(_lightOffCtrl.text);

    setState(() => _isSaving = true);

    try {
      final body = jsonEncode({
        'tempOn':     tempOn,
        'tempOff':    tempOff,
        'tempDanger': tempDanger,
        'humiOn':     humiOn,
        'humiOff':    humiOff,
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
                  label: 'Nhiệt độ BẬT quạt (°C) [Ngưỡng Gốc]',
                  hint: 'Ví dụ: 30',
                  icon: Icons.thermostat_rounded,
                  onChanged: _onTempChanged, // Bắt sự kiện khi gõ
                ),
                const SizedBox(height: 16),
                _buildThresholdField(
                  controller: _tempOffCtrl,
                  label: 'Nhiệt độ TẮT quạt (Tự tính = 90%)',
                  hint: '',
                  icon: Icons.ac_unit_rounded,
                  isReadOnly: true, // Khóa không cho sửa
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Cảm biến Độ ẩm',
              icon: Icons.water_drop_outlined,
              color: const Color(0xFF38BDF8),
              children: [
                _buildThresholdField(
                  controller: _humiOnCtrl,
                  label: 'Độ ẩm CAO — BẬT quạt (%) [Ngưỡng Gốc]',
                  hint: 'Ví dụ: 80',
                  icon: Icons.water_drop_rounded,
                  onChanged: _onHumiChanged,
                ),
                const SizedBox(height: 16),
                _buildThresholdField(
                  controller: _humiOffCtrl,
                  label: 'Độ ẩm THẤP — TẮT quạt (Tự tính = 90%)',
                  hint: '',
                  icon: Icons.water_drop_outlined,
                  isReadOnly: true,
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
                  label: 'Ngưỡng tối — BẬT đèn [Ngưỡng Gốc]',
                  hint: 'Ví dụ: 1000',
                  icon: Icons.wb_sunny_rounded,
                  onChanged: _onLightChanged, // Bắt sự kiện khi gõ
                ),
                const SizedBox(height: 16),
                _buildThresholdField(
                  controller: _lightOffCtrl,
                  label: 'Ngưỡng sáng — TẮT đèn (Tự tính = 120%)',
                  hint: '',
                  icon: Icons.brightness_high_rounded,
                  isReadOnly: true, // Khóa không cho sửa
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
                  label: 'Nhiệt độ NGUY HIỂM kích còi (Tự tính = 120%)',
                  hint: '',
                  icon: Icons.crisis_alert_rounded,
                  isReadOnly: true, // Khóa không cho sửa
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
          const Icon(Icons.auto_awesome_rounded,
              color: Color(0xFF6366F1), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chế độ cấu hình thông minh: Nhập Ngưỡng Gốc, hệ thống sẽ tự động nội suy các ngưỡng Tắt và Báo động.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
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
    bool isReadOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: isReadOnly 
                    ? Colors.white.withValues(alpha: 0.3) 
                    : Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isReadOnly ? const Color(0xFF1E2433) : const Color(0xFF0A0E1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isReadOnly 
                    ? Colors.transparent 
                    : Colors.white.withValues(alpha: 0.1), 
                width: 1),
          ),
          child: TextField(
            controller: controller,
            readOnly: isReadOnly,
            onChanged: onChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                color: isReadOnly 
                    ? Colors.white.withValues(alpha: 0.4) 
                    : Colors.white, 
                fontSize: 15, 
                fontWeight: FontWeight.w600),
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