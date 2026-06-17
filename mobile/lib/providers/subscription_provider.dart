import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

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
      final resp = await ApiService.get('/users/profile');
      if (resp['success'] == true) {
        _activeSubscription = resp['data']['subscription'];
        _dailyUsed = resp['data']['dailyOperationsUsed'] ?? 0;
        _dailyLimit = resp['data']['dailyOperationsLimit'] ?? 0;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }
}
