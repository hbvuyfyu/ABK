import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [usersResp, plansResp] = await Future.wait([
        ApiService.get('/admin/users'),
        ApiService.get('/plans/all'),
      ]);
      if (usersResp['success'] == true) _users = usersResp['data'];
      if (plansResp['success'] == true) _plans = plansResp['data'];
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggleUser(String userId, bool current) async {
    await ApiService.patch('/admin/users/$userId/toggle', null);
    _loadData();
  }

  Future<void> _activateSubscription(String userId) async {
    if (_plans.isEmpty) return;
    String? selectedPlanId = _plans[0]['id'];
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('تفعيل اشتراك', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary)),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButton<String>(
            value: selectedPlanId,
            dropdownColor: AppTheme.cardBg,
            style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary),
            items: _plans.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['nameAr'] ?? p['name']))).toList(),
            onChanged: (v) { setS(() => selectedPlanId = v); },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final resp = await ApiService.post('/admin/subscriptions/activate', {'userId': userId, 'planId': selectedPlanId});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(resp['success'] == true ? 'تم تفعيل الاشتراك' : 'فشل التفعيل', style: const TextStyle(fontFamily: 'Cairo')),
                backgroundColor: resp['success'] == true ? AppTheme.success : AppTheme.error,
              ));
              _loadData();
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('تفعيل', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _users.isEmpty
                  ? const Center(child: Text('لا يوجد مستخدمون', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        final activeSub = (u['subscriptions'] as List?)?.isNotEmpty == true ? u['subscriptions'][0] : null;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.2), child: const Icon(Icons.person, color: AppTheme.primary, size: 20)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(u['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                                          Text(u['email'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12), overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: u['isActive'] == true,
                                      onChanged: (v) => _toggleUser(u['id'], u['isActive'] == true),
                                      activeColor: AppTheme.success,
                                    ),
                                  ],
                                ),
                                if (activeSub != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.success.withOpacity(0.3))),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle, color: AppTheme.success, size: 14),
                                        const SizedBox(width: 6),
                                        Text('مشترك: ${activeSub['plan']?['nameAr'] ?? ''}', style: const TextStyle(color: AppTheme.success, fontFamily: 'Cairo', fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: () => _activateSubscription(u['id']),
                                  icon: const Icon(Icons.add_card, size: 16, color: AppTheme.primary),
                                  label: const Text('تفعيل اشتراك', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.primary, fontSize: 13)),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
