import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/subscription_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sub = context.watch<SubscriptionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gamepad, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('GAME EVENT'),
          ],
        ),
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.accent),
              onPressed: () => context.push('/admin'),
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => sub.loadProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcome(auth),
              const SizedBox(height: 24),
              _buildSubscriptionSection(sub),
              const SizedBox(height: 24),
              _buildQuickActions(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(auth),
    );
  }

  Widget _buildWelcome(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A2B4A), Color(0xFF0D1E3D)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مرحباً بك', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
                Text(auth.user?.name ?? auth.user?.email ?? 'مستخدم',
                  style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.gamepad, color: AppTheme.primary, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionSection(SubscriptionProvider sub) {
    if (sub.isLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('حالة الاشتراك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        if (!sub.hasActive)
          _buildNoSubscription()
        else
          SubscriptionCard(subscription: sub.activeSubscription!, dailyUsed: sub.dailyUsed, dailyLimit: sub.dailyLimit),
      ],
    );
  }

  Widget _buildNoSubscription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.card_membership_outlined, color: AppTheme.textHint, size: 48),
          const SizedBox(height: 12),
          const Text('لا يوجد اشتراك نشط', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/plans'),
            child: const Text('اشترك الآن'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.rocket_launch_outlined, 'label': 'Engine', 'route': '/engine', 'color': AppTheme.accent},
      {'icon': Icons.card_membership_outlined, 'label': 'الباقات', 'route': '/plans', 'color': AppTheme.primary},
      {'icon': Icons.history_outlined, 'label': 'سجل الدفع', 'route': '/profile', 'color': AppTheme.success},
      {'icon': Icons.person_outline, 'label': 'حسابي', 'route': '/profile', 'color': AppTheme.textSecondary},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الوصول السريع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
          ),
          itemCount: actions.length,
          itemBuilder: (_, i) {
            final a = actions[i];
            return InkWell(
              onTap: () => context.push(a['route'] as String),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(a['icon'] as IconData, color: a['color'] as Color, size: 32),
                    const SizedBox(height: 8),
                    Text(a['label'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNav(AuthProvider auth) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) {
        setState(() => _currentIndex = i);
        switch (i) {
          case 0: context.go('/'); break;
          case 1: context.push('/plans'); break;
          case 2: context.push('/engine'); break;
          case 3: context.push('/profile'); break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
        BottomNavigationBarItem(icon: Icon(Icons.card_membership_outlined), label: 'الباقات'),
        BottomNavigationBarItem(icon: Icon(Icons.rocket_launch_outlined), label: 'Engine'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'حسابي'),
      ],
    );
  }
}
