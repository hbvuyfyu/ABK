import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class UsdtPaymentScreen extends StatefulWidget {
  final String paymentId;
  const UsdtPaymentScreen({super.key, required this.paymentId});

  @override
  State<UsdtPaymentScreen> createState() => _UsdtPaymentScreenState();
}

class _UsdtPaymentScreenState extends State<UsdtPaymentScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true;
  final _txidCtrl = TextEditingController();
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _txidCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final resp = await ApiService.get('/settings/payment', auth: false);
      if (resp['success'] == true) setState(() => _settings = resp['data']);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _verifyTxid() async {
    if (_txidCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل TXID أولاً', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    setState(() => _verifying = true);
    try {
      final resp = await ApiService.post('/payments/${widget.paymentId}/verify-txid', {'txid': _txidCtrl.text.trim()});
      if (!mounted) return;
      if (resp['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم التحقق وتفعيل الاشتراك بنجاح!', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppTheme.success,
        ));
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resp['message'] ?? 'فشل التحقق من TXID', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppTheme.error,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('خطأ في الاتصال', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppTheme.error,
      ));
    }
    setState(() => _verifying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدفع بـ USDT'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUsdtInfo(),
                  const SizedBox(height: 24),
                  _buildTxidInput(),
                  const SizedBox(height: 24),
                  GradientButton(onPressed: _verifying ? null : _verifyTxid, isLoading: _verifying, text: 'تحقق وفعّل الاشتراك'),
                ],
              ),
            ),
    );
  }

  Widget _buildUsdtInfo() {
    final address = _settings?['usdt_bep20_address'] ?? '';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.accent.withOpacity(0.15), AppTheme.accent.withOpacity(0.05)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.currency_bitcoin, color: AppTheme.accent, size: 48),
          const SizedBox(height: 12),
          const Text('عنوان USDT BEP20', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
          const SizedBox(height: 8),
          Text(address, textAlign: TextAlign.center, textDirection: TextDirection.ltr,
            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ العنوان', style: TextStyle(fontFamily: 'Cairo')), duration: Duration(seconds: 1)));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('نسخ العنوان', style: TextStyle(fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.black, minimumSize: const Size(0, 40)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.warning.withOpacity(0.3))),
            child: Text(_settings?['usdt_instructions'] ?? 'أرسل USDT على شبكة BEP20 ثم أدخل TXID',
              textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.warning, fontFamily: 'Cairo', fontSize: 12, height: 1.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildTxidInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Transaction ID (TXID)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        TextField(
          controller: _txidCtrl,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(
            labelText: 'أدخل TXID هنا',
            prefixIcon: Icon(Icons.tag, color: AppTheme.primary),
            hintText: '0x...',
          ),
        ),
        const SizedBox(height: 8),
        const Text('سيتم التحقق من المعاملة تلقائياً على البلوكشين', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
      ],
    );
  }
}
