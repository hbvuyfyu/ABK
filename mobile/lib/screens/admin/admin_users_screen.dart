import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final db = Supabase.instance.client;
      final now = DateTime.now().toIso8601String();
      final results = await Future.wait([
        db.from('profiles').select().order('created_at', ascending: false),
        db.from('plans').select().eq('is_active', true),
      ]);
      _users = results[0] as List;
      _plans = results[1] as List;
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _toggleUser(String userId, bool current) async {
    await Supabase.instance.client.from('profiles').update({'is_active': !current}).eq('id', userId);
    _loadData();
  }

  Future<void> _activateSubscription(String userId) async {
    if (_plans.isEmpty) return;
    String? selectedPlanId = _plans[0]['id'] as String;
    await showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.cardBg,
      title: const Text('تفعيل اشتراك', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary)),
      content: StatefulBuilder(builder: (ctx, setS) => DropdownButton<String>(
        value: selectedPlanId, dropdownColor: AppTheme.cardBg,
        style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary),
        items: _plans.map<DropdownMenuItem<String>>((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['name'] as String))).toList(),
        onChanged: (v) { setS(() => selectedPlanId = v); },
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textSecondary))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            final plan = _plans.firstWhere((p) => p['id'] == selectedPlanId);
            final days = (plan['duration_days'] as int?) ?? 30;
            final endDate = DateTime.now().add(Duration(days: days)).toIso8601String();
            await Supabase.instance.client.from('subscriptions').upsert({'user_id': userId, 'plan_id': selectedPlanId, 'end_date': endDate, 'status': 'ACTIVE', 'daily_operations_used': 0});
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفعيل الاشتراك', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.success));
            _loadData();
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
          child: const Text('تفعيل', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(onRefresh: _loadData, child: _users.isEmpty
              ? const Center(child: Text('لا يوجد مستخدمون', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')))
              : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _users.length, itemBuilder: (_, i) {
                  final u = _users[i];
                  return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.2), child: const Icon(Icons.person, color: AppTheme.primary, size: 20)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u['name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                        Text(u['email'] ?? '', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12), overflow: TextOverflow.ellipsis),
                      ])),
                      Switch(value: u['is_active'] == true, onChanged: (_) => _toggleUser(u['id'], u['is_active'] == true), activeColor: AppTheme.success),
                    ]),
                    const SizedBox(height: 12),
                    TextButton.icon(onPressed: () => _activateSubscription(u['id']), icon: const Icon(Icons.add_card, size: 16, color: AppTheme.primary), label: const Text('تفعيل اشتراك', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.primary, fontSize: 13)), style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0))),
                  ])));
                })),
    );
  }
}