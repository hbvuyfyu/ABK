import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadStats(); }

  Future<void> _loadStats() async {
    try {
      final db = Supabase.instance.client;
      final now = DateTime.now().toIso8601String();
      final results = await Future.wait([
        db.from('profiles').select('id', const FetchOptions(count: CountOption.exact, head: true)),
        db.from('subscriptions').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('status', 'ACTIVE').gte('end_date', now),
        db.from('payments').select('id', const FetchOptions(count: CountOption.exact, head: true)).eq('status', 'PENDING'),
        db.from('payments').select('amount').eq('status', 'APPROVED'),
      ]);
      final revenue = (results[3] as List).fold<double>(0, (s, p) => s + (double.tryParse('${p['amount']}') ?? 0));
      setState(() {
        _stats = {
          'totalUsers': results[0].count ?? 0,
          'activeSubscriptions': results[1].count ?? 0,
          'pendingPayments': results[2].count ?? 0,
          'totalRevenue': revenue,
        };
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.admin_panel_settings_outlined, color: AppTheme.accent, size: 22),
          SizedBox(width: 8), Text('لوحة الأدمن'),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.go('/')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildStatsGrid(), const SizedBox(height: 24), _buildAdminMenu(context),
                ]),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {'label': 'إجمالي المستخدمين', 'value': '${_stats?['totalUsers'] ?? 0}', 'icon': Icons.people_outline, 'color': AppTheme.primary},
      {'label': 'اشتراكات نشطة', 'value': '${_stats?['activeSubscriptions'] ?? 0}', 'icon': Icons.card_membership_outlined, 'color': AppTheme.success},
      {'label': 'طلبات معلقة', 'value': '${_stats?['pendingPayments'] ?? 0}', 'icon': Icons.pending_actions_outlined, 'color': AppTheme.warning},
      {'label': 'إجمالي الأرباح', 'value': '\$${(_stats?['totalRevenue'] ?? 0.0).toStringAsFixed(2)}', 'icon': Icons.attach_money_outlined, 'color': AppTheme.accent},
    ];
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: (s['color'] as Color).withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(s['icon'] as IconData, color: s['color'] as Color, size: 28),
            const Spacer(),
            Text(s['value'] as String, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: s['color'] as Color, fontFamily: 'Cairo')),
            Text(s['label'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
          ]),
        );
      },
    );
  }

  Widget _buildAdminMenu(BuildContext context) {
    final items = [
      {'label': 'إدارة المستخدمين', 'icon': Icons.people_outline, 'route': '/admin/users', 'color': AppTheme.primary},
      {'label': 'إدارة المدفوعات', 'icon': Icons.payment_outlined, 'route': '/admin/payments', 'color': AppTheme.success},
      {'label': 'إدارة الباقات', 'icon': Icons.card_membership_outlined, 'route': '/admin/plans', 'color': AppTheme.accent},
      {'label': 'الإعدادات', 'icon': Icons.settings_outlined, 'route': '/admin/settings', 'color': AppTheme.textSecondary},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('الإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
      const SizedBox(height: 12),
      ...items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => context.push(item['route'] as String),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22)),
              const SizedBox(width: 16),
              Text(item['label'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.textHint, size: 16),
            ]),
          ),
        ),
      )),
    ]);
  }
}