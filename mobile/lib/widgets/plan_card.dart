import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isPopular;
  final VoidCallback onSelect;

  const PlanCard({super.key, required this.plan, this.isPopular = false, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: isPopular
                ? LinearGradient(colors: [AppTheme.primary.withOpacity(0.2), AppTheme.primaryDark.withOpacity(0.1)])
                : null,
            color: isPopular ? null : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPopular ? AppTheme.primary : AppTheme.border,
              width: isPopular ? 2 : 1,
            ),
            boxShadow: isPopular
                ? [BoxShadow(color: AppTheme.primary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 8))]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['nameAr'] ?? plan['name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                        const SizedBox(height: 4),
                        Text('${plan['durationDays']} يوم', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('\$${plan['price']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accent, fontFamily: 'Cairo')),
                      const Text('لمرة واحدة', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 12),
              _featureRow(Icons.bolt_outlined, '${plan['dailyOperations']} عملية يومياً', AppTheme.primary),
              const SizedBox(height: 8),
              _featureRow(Icons.calendar_today_outlined, 'صالح ${plan['durationDays']} يوم', AppTheme.success),
              const SizedBox(height: 8),
              _featureRow(Icons.refresh, 'إعادة ضبط يومي تلقائي', AppTheme.accent),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onSelect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPopular ? AppTheme.primary : AppTheme.surfaceVariant,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('اختر هذه الباقة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.accent, Color(0xFFFF6B35)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('الأكثر شيوعاً', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 14)),
      ],
    );
  }
}
