import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final resp = await ApiService.get('/plans/all');
      if (resp['success'] == true) setState(() => _plans = resp['data']);
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _editPlan(Map<String, dynamic> plan) {
    final nameCtrl = TextEditingController(text: plan['name']);
    final nameArCtrl = TextEditingController(text: plan['nameAr']);
    final priceCtrl = TextEditingController(text: '${plan['price']}');
    final daysCtrl = TextEditingController(text: '${plan['durationDays']}');
    final opsCtrl = TextEditingController(text: '${plan['dailyOperations']}');
    bool isActive = plan['isActive'] == true;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('تعديل: ${plan['nameAr']}', style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary)),
        content: StatefulBuilder(
          builder: (ctx, setS) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameArCtrl, decoration: const InputDecoration(labelText: 'الاسم بالعربي')),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (EN)')),
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر (\$)')),
                const SizedBox(height: 12),
                TextField(controller: daysCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المدة (أيام)')),
                const SizedBox(height: 12),
                TextField(controller: opsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمليات اليومية')),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: isActive,
                  onChanged: (v) => setS(() => isActive = v),
                  title: const Text('مفعّل', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary)),
                  activeColor: AppTheme.success,
                  tileColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final resp = await ApiService.put('/admin/plans/${plan['id']}', {
                'name': nameCtrl.text,
                'nameAr': nameArCtrl.text,
                'price': double.tryParse(priceCtrl.text) ?? plan['price'],
                'durationDays': int.tryParse(daysCtrl.text) ?? plan['durationDays'],
                'dailyOperations': int.tryParse(opsCtrl.text) ?? plan['dailyOperations'],
                'isActive': isActive,
              });
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(resp['success'] == true ? 'تم تحديث الباقة' : 'فشل التحديث', style: const TextStyle(fontFamily: 'Cairo')),
                backgroundColor: resp['success'] == true ? AppTheme.success : AppTheme.error,
              ));
              _loadPlans();
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الباقات'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (_, i) {
                final p = _plans[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(p['nameAr'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo'))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: p['isActive'] == true ? AppTheme.success.withOpacity(0.15) : AppTheme.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(p['isActive'] == true ? 'مفعّل' : 'معطّل',
                                style: TextStyle(color: p['isActive'] == true ? AppTheme.success : AppTheme.error, fontFamily: 'Cairo', fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _infoChip(Icons.attach_money, '\$${p['price']}', AppTheme.accent),
                            const SizedBox(width: 8),
                            _infoChip(Icons.calendar_today_outlined, '${p['durationDays']} يوم', AppTheme.primary),
                            const SizedBox(width: 8),
                            _infoChip(Icons.bolt_outlined, '${p['dailyOperations']} عملية', AppTheme.success),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _editPlan(p),
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                            label: const Text('تعديل', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.primary)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary), minimumSize: const Size(0, 44)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
