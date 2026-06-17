import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _payments = [];
  List<dynamic> _subscriptions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final [paymentsResp, subsResp] = await Future.wait([
        ApiService.get('/users/payment-history'),
        ApiService.get('/users/subscription-history'),
      ]);
      if (paymentsResp['success'] == true) _payments = paymentsResp['data'];
      if (subsResp['success'] == true) _subscriptions = subsResp['data'];
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.go('/')),
        actions: [
          TextButton(
            onPressed: () async {
              await auth.logout();
              if (mounted) context.go('/login');
            },
            child: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.error, fontFamily: 'Cairo')),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(auth, sub),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'المدفوعات'), Tab(text: 'الاشتراكات')],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [_buildPaymentsList(), _buildSubscriptionsList()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(AuthProvider auth, SubscriptionProvider sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppTheme.surface,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.primary.withOpacity(0.2),
            child: const Icon(Icons.person, color: AppTheme.primary, size: 32),
          ),
          const SizedBox(height: 12),
          Text(auth.user?.name ?? 'مستخدم', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
          Text(auth.user?.email ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          if (sub.hasActive) Row(
            children: [
              Expanded(child: _statTile('الاشتراك', sub.activeSubscription?['plan']?['nameAr'] ?? 'نشط', AppTheme.success)),
              Expanded(child: _statTile('العمليات اليوم', '${sub.dailyUsed}/${sub.dailyLimit}', AppTheme.primary)),
              Expanded(child: _statTile('المتبقي', '${sub.dailyLimit - sub.dailyUsed}', AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, fontFamily: 'Cairo')),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildPaymentsList() {
    if (_payments.isEmpty) return const Center(child: Text('لا توجد مدفوعات', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (_, i) {
        final p = _payments[i];
        final status = p['status'] as String;
        Color statusColor = status == 'APPROVED' ? AppTheme.success : status == 'REJECTED' ? AppTheme.error : AppTheme.warning;
        String statusLabel = status == 'APPROVED' ? 'مقبول' : status == 'REJECTED' ? 'مرفوض' : 'قيد المراجعة';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.receipt_outlined, color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['plan']?['nameAr'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                      Text(_formatMethod(p['method']), style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'Cairo', fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionsList() {
    if (_subscriptions.isEmpty) return const Center(child: Text('لا توجد اشتراكات', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subscriptions.length,
      itemBuilder: (_, i) {
        final s = _subscriptions[i];
        final isActive = s['status'] == 'ACTIVE' && DateTime.tryParse(s['endDate'])?.isAfter(DateTime.now()) == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (isActive ? AppTheme.success : AppTheme.textHint).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.card_membership, color: isActive ? AppTheme.success : AppTheme.textHint, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['plan']?['nameAr'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                      Text('ينتهي: ${_formatDate(s['endDate'])}', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive ? AppTheme.success : AppTheme.textHint).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isActive ? 'نشط' : 'منتهي', style: TextStyle(color: isActive ? AppTheme.success : AppTheme.textHint, fontFamily: 'Cairo', fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatMethod(String method) {
    switch (method) {
      case 'SHAM_CASH': return 'Sham Cash';
      case 'SYRIATEL_CASH': return 'Syriatel Cash';
      case 'USDT_BEP20': return 'USDT BEP20';
      default: return method;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    return DateFormat('yyyy/MM/dd').format(date);
  }
}
