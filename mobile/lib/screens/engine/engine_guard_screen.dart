import 'package:flutter/material.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'jumper_engine_screen.dart';

class EngineGuardScreen extends StatefulWidget {
  const EngineGuardScreen({super.key});
  @override
  State<EngineGuardScreen> createState() => _EngineGuardScreenState();
}

class _EngineGuardScreenState extends State<EngineGuardScreen>
    with SingleTickerProviderStateMixin {
  bool _checking = true;
  bool _isRooted = false;
  bool _rootGranted = false;

  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _checkRoot();
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<bool> _detectRoot() async {
    final rootPaths = [
      '/system/app/Superuser.apk', '/sbin/su', '/system/bin/su',
      '/system/xbin/su', '/data/local/xbin/su', '/data/local/bin/su',
      '/data/local/su', '/system/sd/xbin/su', '/system/bin/failsafe/su',
      '/dev/com.koushikdutta.superuser.daemon/',
    ];
    for (final path in rootPaths) {
      if (await File(path).exists()) return true;
    }
    try {
      final result = await Process.run('su', ['-c', 'id']);
      if (result.exitCode == 0) return true;
    } catch (_) {}
    return false;
  }

  Future<void> _checkRoot() async {
    try {
      final rooted = await _detectRoot();
      setState(() { _isRooted = rooted; _checking = false; });
      if (rooted) await _requestRootAccess();
    } catch (_) {
      setState(() => _checking = false);
    }
  }

  Future<void> _requestRootAccess() async {
    try {
      final result = await Process.run('su', ['-c', 'id']);
      setState(() => _rootGranted = result.exitCode == 0);
    } catch (_) {
      setState(() => _rootGranted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: AppTheme.accent),
          SizedBox(height: 16),
          Text('جاري التحقق من الصلاحيات...', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
        ])),
      );
    }
    if (!_isRooted || !_rootGranted) return _buildLockedScreen();
    return _buildEngineScreen();
  }

  Widget _buildLockedScreen() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) context.go('/'); },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: AppTheme.error.withOpacity(0.3), width: 2)),
            child: const Icon(Icons.lock, color: AppTheme.error, size: 64),
          ),
          const SizedBox(height: 32),
          const Text('الوصول مرفوض', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.error, fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.error.withOpacity(0.3))),
            child: Column(children: [
              const Icon(Icons.security, color: AppTheme.error, size: 32),
              const SizedBox(height: 12),
              const Text('صفحة Engine تتطلب صلاحيات Root', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
              const SizedBox(height: 8),
              Text(_isRooted ? 'تم رفض صلاحيات Root. يرجى الموافقة عند طلب الصلاحية.' : 'هذا الجهاز غير مروّت.', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 14, height: 1.6)),
            ]),
          ),
          const SizedBox(height: 32),
          if (_isRooted)
            ElevatedButton.icon(
              onPressed: () { setState(() => _checking = true); _requestRootAccess().then((_) => setState(() => _checking = false)); },
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
        ]))),
      ),
    );
  }

  Widget _buildEngineScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.rocket_launch, color: AppTheme.accent, size: 22),
          SizedBox(width: 8),
          Text('Engine'),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.go('/')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Glowing Engine Icon
            AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.accent.withOpacity(_glow.value), width: 2),
                  boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(_glow.value * 0.3), blurRadius: 40, spreadRadius: 8)],
                ),
                child: const Icon(Icons.rocket_launch, color: AppTheme.accent, size: 64),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Engine', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accent, fontFamily: 'Cairo', letterSpacing: 2)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.success.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Text('Root Access Granted', style: TextStyle(color: AppTheme.success, fontFamily: 'Cairo', fontSize: 12)),
              ]),
            ),

            const SizedBox(height: 48),

            // ── JuMper Engine Button ────────────────────────────────────────
            AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withOpacity(_glow.value * 0.4), blurRadius: 30, spreadRadius: 4)],
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JumperEngineScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF88),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Text('⚡', style: TextStyle(fontSize: 28, color: Colors.black)),
                      SizedBox(width: 14),
                      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('محرك الجمبرة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Colors.black)),
                        Text('07-JuMper Script Engine', style: TextStyle(fontSize: 11, fontFamily: 'Courier', color: Color(0xFF005500), letterSpacing: 1.5)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF001A0A), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.15))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Color(0xFF00FF88), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'يعرض جميع التطبيقات المفتوحة ويُشغّل سكريبت الجمبرة على ما تختاره',
                  style: TextStyle(color: const Color(0xFF00FF88).withOpacity(0.8), fontFamily: 'Cairo', fontSize: 12, height: 1.5),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
