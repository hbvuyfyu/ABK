import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  void initState() { super.initState(); _loadSettings(); }
  @override
  void dispose() { _controllers.forEach((_, c) => c.dispose()); super.dispose(); }

  Future<void> _loadSettings() async {
    try {
      final data = await Supabase.instance.client.from('settings').select().order('key');
      _settings = data;
      for (final s in _settings) {
        _controllers[s['key']] = TextEditingController(text: s['value']);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    try {
      final updates = _settings.map((s) => {'key': s['key'], 'value': _controllers[s['key']]?.text ?? s['value'], 'updated_at': DateTime.now().toIso8601String()}).toList();
      await Supabase.instance.client.from('settings').upsert(updates);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.success));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الحفظ', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.error));
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ..._settings.map((s) => Padding(padding: const EdgeInsets.only(bottom: 16), child: TextField(controller: _controllers[s['key']], decoration: InputDecoration(labelText: s['key'])))),
              GradientButton(onPressed: _saving ? null : _saveAll, isLoading: _saving, text: 'حفظ الإعدادات'),
            ])),
    );
  }
}