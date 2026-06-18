import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionProvider extends ChangeNotifier {
  Map<String, dynamic>? _activeSubscription;
  int _dailyUsed = 0;
  int _dailyLimit = 0;
  bool _isLoading = false;

  Map<String, dynamic>? get activeSubscription => _activeSubscription;
  int get dailyUsed => _dailyUsed;
  int get dailyLimit => _dailyLimit;
  bool get isLoading => _isLoading;
  bool get hasActive => _activeSubscription != null;

  Future<void> loadProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final now = DateTime.now().toIso8601String();
      final data = await Supabase.instance.client
          .from('subscriptions')
          .select('*, plans(*)')
          .eq('user_id', uid)
          .eq('status', 'ACTIVE')
          .gte('end_date', now)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      _activeSubscription = data;
      _dailyUsed = data?['daily_operations_used'] ?? 0;
      _dailyLimit = data?['plans']?['daily_operations'] ?? 0;
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
