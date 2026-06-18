import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class UsdtPaymentScreen extends StatefulWidget {
  final String paymentId;
  const UsdtPaymentScreen({super.key, required this.paymentId});
  @override
  State<UsdtPaymentScreen> createState() => _UsdtPaymentScreenState();
}

class _UsdtPaymentScreenState extends State<UsdtPaymentScreen> {
  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _settings;
  bool _loading = true;
  final _txidCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() { super.initState(); _loadData(); }
  @override
  void dispose() { _txidCtrl.dispose(); super.dispose(); }

  Future<void> _loadData() async {
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait([
        db.from('payments').select('*, plans(name,price)').eq('id', widget.paymentId).maybeSingle(),
        db.from('settings').select(),
      ]);
      _payment = results[0] as Map<String, dynamic>?;
      final settingsList = results[1] as List;
      _settings = {for (final s in settingsList) s['key']: s['value']};
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (_txidCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل TXID أولاً', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.warning));
      return;
    }
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('payments').update({'txid': _txidCtrl.text.trim()}).eq('id', widget.paymentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال TXID، انتظر موافقة الأدمن', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.success));
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الإرسال', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.error));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final address = _settings?['usdt_address'] ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('دفع USDT BEP20'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('عنوان المحفظة (BEP20)', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text(address, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontFamily: 'Courier'), overflow: TextOverflow.ellipsis)),
                  IconButton(icon: const Icon(Icons.copy, color: AppTheme.primary, size: 20), onPressed: () { Clipboard.setData(ClipboardData(text: address)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ', style: TextStyle(fontFamily: 'Cairo')), duration: Duration(seconds: 1))); }),
                ]),
                const Divider(color: AppTheme.border),
                Text('المبلغ: \$${_payment?['amount'] ?? ''}', style: const TextStyle(color: AppTheme.accent, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
              ])),
              const SizedBox(height: 24),
              const Text('أدخل TXID بعد إتمام التحويل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
              const SizedBox(height: 12),
              TextField(controller: _txidCtrl, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'Transaction ID (TXID)', prefixIcon: Icon(Icons.tag, color: AppTheme.primary))),
              const SizedBox(height: 32),
              GradientButton(onPressed: _submitting ? null : _submit, isLoading: _submitting, text: 'إرسال TXID'),
            ])),
    );
  }
}