import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class EngineGuardScreen extends StatefulWidget {
  const EngineGuardScreen({super.key});

  @override
  State<EngineGuardScreen> createState() => _EngineGuardScreenState();
}

class _EngineGuardScreenState extends State<EngineGuardScreen> {
  bool _checking = true;
  bool _isRooted = false;
  bool _rootGranted = false;

  @override
  void initState() {
    super.initState();
    _checkRoot();
  }

  Future<bool> _detectRoot() async {
    // Check for common root indicators
    final rootPaths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/data/local/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/dev/com.koushikdutta.superuser.daemon/',
    ];
    for (final path in rootPaths) {
      if (await File(path).exists()) return true;
    }
    // Try to run su
    try {
      final result = await Process.run('su', ['-c', 'id']);
      if (result.exitCode == 0) return true;
    } catch (_) {}
    return false;
  }

  Future<void> _checkRoot() async {
    try {
      final rooted = await _detectRoot();
      setState(() {
        _isRooted = rooted;
        _checking = false;
      });
      if (rooted) {
        await _requestRootAccess();
      }
    } catch (_) {
      setState(() => _checking = false);
    }
  }

  Future<void> _requestRootAccess() async {
    try {
      final result = await Process.run('su', ['-c', 'id']);
      if (result.exitCode == 0) {
        setState(() => _rootGranted = true);
      }
    } catch (_) {
      setState(() => _rootGranted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppTheme.accent),
              const SizedBox(height: 16),
              const Text('جاري التحقق من الصلاحيات...', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
            ],
          ),
        ),
      );
    }

    if (!_isRooted || !_rootGranted) {
      return _buildLockedScreen();
    }

    return _buildEngineScreen();
  }

  Widget _buildLockedScreen() {
    return WillPopScope(
      onWillPop: () async {
        context.go('/');
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.lock, color: AppTheme.error, size: 64),
                ),
                const SizedBox(height: 32),
                const Text(
                  'الوصول مرفوض',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.error, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.security, color: AppTheme.error, size: 32),
                      const SizedBox(height: 12),
                      const Text(
                        'صفحة Engine تتطلب صلاحيات Root',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRooted
                            ? 'تم رفض صلاحيات Root. يرجى الموافقة عند طلب الصلاحية.'
                            : 'هذا الجهاز غير مروّت. يجب أن يكون الجهاز مروّتاً للوصول إلى هذه الصفحة.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 14, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_isRooted)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() => _checking = true);
                      _requestRootAccess().then((_) => setState(() => _checking = false));
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('طلب صلاحية Root مجدداً', style: TextStyle(fontFamily: 'Cairo')),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back, color: AppTheme.textSecondary),
                  label: const Text('العودة للرئيسية', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.border)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEngineScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, color: AppTheme.accent, size: 22),
            SizedBox(width: 8),
            Text('Engine'),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.go('/')),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent.withOpacity(0.3), width: 2),
                boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.2), blurRadius: 30)],
              ),
              child: const Icon(Icons.rocket_launch, color: AppTheme.accent, size: 64),
            ),
            const SizedBox(height: 24),
            const Text('Engine', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accent, fontFamily: 'Cairo', letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('Root Access Granted', style: TextStyle(color: AppTheme.success, fontFamily: 'Cairo', fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
