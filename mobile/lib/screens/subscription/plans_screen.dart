import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/plan_card.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});
  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadPlans(); }

  Future<void> _loadPlans() async {
    try {
      final data = await Supabase.instance.client.from('plans').select().eq('is_active', true).order('price');
      setState(() { _plans = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('باقات الاشتراك'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.go('/'))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('اختر الباقة المناسبة لك', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
              const SizedBox(height: 8),
              const Text('اشتراك واحد نشط فقط في كل مرة', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
              const SizedBox(height: 24),
              ..._plans.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: PlanCard(plan: e.value, isPopular: e.key == 1, onSelect: () => context.push('/payment/${e.value['id']}')))),
            ])),
    );
  }
}