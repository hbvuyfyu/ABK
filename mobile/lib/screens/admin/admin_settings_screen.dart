import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  List<dynamic> _settings = [];
  bool _loading = true;
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final resp = await ApiService.get('/settings');
      if (resp['success'] == true) {
        _settings = resp['data'];
        for (final s in _settings) {
          _controllers[s['key']] = TextEditingController(text: s['value']);
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final settings = _settings.map((s) => {'key': s['key'], 'value': _controllers[s['key']]?.text ?? s['value'], 'group': s['group']}).toList();
      final resp = await ApiService.put('/settings/bulk', {'settings': settings});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resp['success'] == true ? 'تم حفظ الإعدادات' : 'فشل الحفظ', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: resp['success'] == true ? AppTheme.success : AppTheme.error,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خطأ في الاتصال', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.error));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<dynamic>>{};
    for (final s in _settings) {
      final g = s['group'] as String;
      groups.putIfAbsent(g, () => []).add(s);
    }

    final groupLabels = {'general': 'عام', 'payment': 'الدفع', 'cloudinary': 'Cloudinary', 'blockchain': 'البلوكشين'};

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...groups.entries.map((e) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupLabels[e.key] ?? e.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent, fontFamily: 'Cairo')),
                      const SizedBox(height: 12),
                      ...e.value.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _controllers[s['key']],
                          decoration: InputDecoration(labelText: _formatKey(s['key'])),
                          maxLines: s['key'].toString().contains('instructions') ? 3 : 1,
                        ),
                      )),
                      const SizedBox(height: 8),
                    ],
                  )),
                  GradientButton(onPressed: _saving ? null : _saveAll, isLoading: _saving, text: 'حفظ الإعدادات'),
                ],
              ),
            ),
    );
  }

  String _formatKey(String key) {
    final map = {
      'app_name': 'اسم التطبيق (EN)',
      'app_name_ar': 'اسم التطبيق (AR)',
      'sham_cash_address': 'رقم Sham Cash',
      'syriatel_cash_address': 'رقم Syriatel Cash',
      'usdt_bep20_address': 'عنوان USDT BEP20',
      'sham_cash_instructions': 'تعليمات Sham Cash',
      'syriatel_cash_instructions': 'تعليمات Syriatel Cash',
      'usdt_instructions': 'تعليمات USDT',
      'cloudinary_cloud_name': 'Cloudinary Cloud Name',
      'cloudinary_api_key': 'Cloudinary API Key',
      'cloudinary_api_secret': 'Cloudinary API Secret',
      'bscscan_api_key': 'BSCScan API Key',
      'usdt_contract_address': 'عقد USDT BEP20',
      'min_usdt_confirmations': 'الحد الأدنى للتأكيدات',
    };
    return map[key] ?? key;
  }
}
