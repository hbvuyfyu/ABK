import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class PaymentScreen extends StatefulWidget {
  final String planId;
  const PaymentScreen({super.key, required this.planId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  Map<String, dynamic>? _plan;
  Map<String, dynamic>? _paymentSettings;
  bool _loading = true;
  String? _selectedMethod;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [planResp, settingsResp] = await Future.wait([
        ApiService.get('/plans', auth: false),
        ApiService.get('/settings/payment', auth: false),
      ]);
      if (planResp['success'] == true) {
        final plans = planResp['data'] as List;
        _plan = plans.firstWhere((p) => p['id'] == widget.planId, orElse: () => null);
      }
      if (settingsResp['success'] == true) {
        _paymentSettings = settingsResp['data'];
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _proceedToPayment() async {
    if (_selectedMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('اختر طريقة الدفع أولاً', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    setState(() => _processing = true);
    try {
      final resp = await ApiService.post('/payments', {'planId': widget.planId, 'method': _selectedMethod});
      if (resp['success'] == true) {
        final paymentId = resp['data']['id'];
        if (!mounted) return;
        if (_selectedMethod == 'USDT_BEP20') {
          context.push('/payment/$paymentId/usdt');
        } else {
          context.push('/payment/$paymentId/proof');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resp['message'] ?? 'فشل في إنشاء طلب الدفع', style: const TextStyle(fontFamily: 'Cairo')),
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
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الدفع'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlanSummary(),
                  const SizedBox(height: 24),
                  _buildPaymentMethods(),
                  const SizedBox(height: 24),
                  GradientButton(onPressed: _processing ? null : _proceedToPayment, isLoading: _processing, text: 'متابعة'),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanSummary() {
    if (_plan == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary.withOpacity(0.2), AppTheme.primaryDark.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_plan!['nameAr'] ?? _plan!['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                Text('${_plan!['durationDays']} يوم | ${_plan!['dailyOperations']} عملية/يوم',
                  style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
              ],
            ),
          ),
          Text('\$${_plan!['price']}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.accent, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      {'value': 'SHAM_CASH', 'label': 'Sham Cash', 'icon': Icons.account_balance_wallet_outlined, 'color': AppTheme.primary},
      {'value': 'SYRIATEL_CASH', 'label': 'Syriatel Cash', 'icon': Icons.phone_android_outlined, 'color': AppTheme.success},
      {'value': 'USDT_BEP20', 'label': 'USDT BEP20', 'icon': Icons.currency_bitcoin, 'color': AppTheme.accent},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('طريقة الدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        ...methods.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => _selectedMethod = m['value'] as String),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _selectedMethod == m['value'] ? (m['color'] as Color).withOpacity(0.15) : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedMethod == m['value'] ? (m['color'] as Color) : AppTheme.border,
                  width: _selectedMethod == m['value'] ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(m['icon'] as IconData, color: m['color'] as Color, size: 28),
                  const SizedBox(width: 16),
                  Text(m['label'] as String, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _selectedMethod == m['value'] ? AppTheme.textPrimary : AppTheme.textSecondary, fontFamily: 'Cairo')),
                  const Spacer(),
                  if (_selectedMethod == m['value'])
                    Icon(Icons.check_circle, color: m['color'] as Color, size: 24),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }
}
