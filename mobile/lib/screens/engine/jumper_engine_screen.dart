import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

// ────────────────────────────────────────────────────────────────────────────
// MethodChannel bridge
// ────────────────────────────────────────────────────────────────────────────
class JumperBridge {
  static const _ch = MethodChannel('com.gamevent.app/jumper');

  static Future<List<Map<String, dynamic>>> getRunningApps() async {
    final raw = await _ch.invokeListMethod<Map>('getRunningApps') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Inject into the selected app by PID (most reliable) with packageName as fallback
  static Future<Map<String, dynamic>> runJumper({
    required int pid,
    required String packageName,
  }) async {
    final raw = await _ch.invokeMapMethod<String, dynamic>(
      'runJumper',
      {'pid': pid, 'packageName': packageName},
    );
    return Map<String, dynamic>.from(raw ?? {});
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Main Screen
// ────────────────────────────────────────────────────────────────────────────
class JumperEngineScreen extends StatefulWidget {
  const JumperEngineScreen({super.key});
  @override
  State<JumperEngineScreen> createState() => _JumperEngineScreenState();
}

class _JumperEngineScreenState extends State<JumperEngineScreen>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.idle;
  List<Map<String, dynamic>> _apps = [];
  Map<String, dynamic>? _selected;
  List<String> _consoleLines = [];
  bool? _success;
  bool _isFridaMissing = false;

  late final AnimationController _glowCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _glow;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _glow  = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Load running apps ──────────────────────────────────────────────────────
  Future<void> _openAppPicker() async {
    setState(() { _phase = _Phase.loadingApps; });
    try {
      final apps = await JumperBridge.getRunningApps();
      if (!mounted) return;
      if (apps.isEmpty) {
        _showSnack('لم يتم العثور على تطبيقات مفتوحة');
        setState(() => _phase = _Phase.idle);
        return;
      }
      setState(() { _apps = apps; _phase = _Phase.idle; });
      _showAppPicker();
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشل جلب التطبيقات: $e');
      setState(() => _phase = _Phase.idle);
    }
  }

  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppPickerSheet(
        apps: _apps,
        onSelected: (app) { Navigator.pop(context); _executeJumper(app); },
      ),
    );
  }

  // ── Execute Frida injection ─────────────────────────────────────────────────
  Future<void> _executeJumper(Map<String, dynamic> app) async {
    final pid        = app['pid'] as int? ?? -1;
    final pkgName    = app['package'] as String? ?? '';
    final appName    = app['name'] as String? ?? pkgName;

    setState(() {
      _selected     = app;
      _phase        = _Phase.running;
      _consoleLines = [];
      _success      = null;
    });

    // Animated pre-injection console lines
    final preLines = [
      '[*] 07-JUMPER initialising...',
      '[*] Target app : $appName',
      '[*] Package    : $pkgName',
      '[*] Process PID: ${pid > 0 ? pid.toString() : "resolving..."}',
      '[*] Copying script to /data/local/tmp/jumper_07.js',
      '[*] Connecting to Frida server on USB...',
      '[*] Attaching to process via PID $pid...',
      '[*] Script loaded — waiting for Java runtime...',
    ];
    for (final line in preLines) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() => _consoleLines.add(line));
    }

    try {
      final result = await JumperBridge.runJumper(pid: pid, packageName: pkgName);
      if (!mounted) return;

      final success   = result['success'] as bool? ?? false;
      final rawOutput = result['output'] as String? ?? '';
      final errorMsg  = result['error'] as String? ?? '';

      // Show all output lines
      for (final line in rawOutput.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        await Future.delayed(const Duration(milliseconds: 80));
        if (!mounted) return;
        setState(() => _consoleLines.add(trimmed));
      }

      // Show error if any
      if (errorMsg.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        setState(() => _consoleLines.add('[-] $errorMsg'));
      }

      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() { _success = success; _phase = _Phase.done; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _consoleLines.add('[-] Flutter error: $e');
        _success = false;
        _phase   = _Phase.done;
      });
    }
  }

  void _reset() => setState(() {
    _phase = _Phase.idle; _selected = null; _consoleLines = []; _success = null; _isFridaMissing = false;
  });

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: AppTheme.error,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Icon(Icons.electric_bolt,
                color: const Color(0xFF00FF88).withOpacity(_glow.value), size: 22),
          ),
          const SizedBox(width: 8),
          const Text('محرك الجمبرة',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ]),
      ),
      body: switch (_phase) {
        _Phase.idle        => _buildIdle(),
        _Phase.loadingApps => _buildLoadingApps(),
        _Phase.running || _Phase.done => _buildConsole(),
      },
    );
  }

  // ── Idle ───────────────────────────────────────────────────────────────────
  Widget _buildIdle() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(
          animation: _glow,
          builder: (_, __) => Container(
            width: 140, height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF001A0A),
              border: Border.all(color: const Color(0xFF00FF88).withOpacity(_glow.value), width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFF00FF88).withOpacity(_glow.value * 0.4), blurRadius: 40, spreadRadius: 10)],
            ),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 64))),
          ),
        ),
        const SizedBox(height: 28),
        const Text('محرك الجمبرة',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00FF88), fontFamily: 'Cairo', letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('07-JuMper · PID Injection Engine',
            style: TextStyle(fontSize: 12, color: Color(0xFF005500), fontFamily: 'Courier', letterSpacing: 2)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF001A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
          ),
          child: const Text(
            'يحقن السكريبت مباشرةً داخل عملية التطبيق\nعبر Frida PID Injection\nويُرسل event: power_5w عبر AppsFlyer',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF88FFBB), fontFamily: 'Cairo', fontSize: 13, height: 1.7),
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openAppPicker,
            icon: const Icon(Icons.rocket_launch, size: 22),
            label: const Text('اختر تطبيقاً وابدأ الحقن',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF88),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    ),
  );

  // ── Loading apps ───────────────────────────────────────────────────────────
  Widget _buildLoadingApps() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Transform.scale(
          scale: _pulse.value,
          child: const Icon(Icons.apps, color: Color(0xFF00FF88), size: 64),
        ),
      ),
      const SizedBox(height: 24),
      const Text('جاري جلب التطبيقات والـ PIDs...',
          style: TextStyle(color: Color(0xFF00FF88), fontFamily: 'Cairo', fontSize: 16)),
      const SizedBox(height: 16),
      const SizedBox(width: 200,
          child: LinearProgressIndicator(color: Color(0xFF00FF88), backgroundColor: Color(0xFF001A0A))),
    ]),
  );

  // ── Console + Result ───────────────────────────────────────────────────────
  Widget _buildConsole() {
    final isRunning = _phase == _Phase.running;
    final isSuccess = _success == true;

    return Column(children: [
      // Target app header
      if (_selected != null)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF001A0A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
          ),
          child: Row(children: [
            _AppIcon(iconBase64: _selected!['icon'] as String? ?? '', size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_selected!['name'] as String? ?? '',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
              Text(_selected!['package'] as String? ?? '',
                  style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'Courier', fontSize: 10),
                  overflow: TextOverflow.ellipsis),
              Text('PID: ${_selected!['pid'] ?? "?"}',
                  style: const TextStyle(color: Color(0xFF005500), fontFamily: 'Courier', fontSize: 10)),
            ])),
            const SizedBox(width: 8),
            if (isRunning)
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(width: 12, height: 12,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00FF88).withOpacity(_pulse.value))),
              )
            else
              Icon(isSuccess ? Icons.check_circle : Icons.cancel,
                  color: isSuccess ? const Color(0xFF00FF88) : AppTheme.error, size: 28),
          ]),
        ),

      // Terminal console
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF050D08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.15)),
          ),
          child: Column(children: [
            Row(children: [
              _termDot(const Color(0xFFFF5F57)),
              const SizedBox(width: 6),
              _termDot(const Color(0xFFFFBD2E)),
              const SizedBox(width: 6),
              _termDot(const Color(0xFF28CA41)),
              const SizedBox(width: 12),
              const Text('frida · pid injection',
                  style: TextStyle(color: Color(0xFF334433), fontFamily: 'Courier', fontSize: 11)),
              const Spacer(),
              if (isRunning)
                const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FF88))),
            ]),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF0D1F0D), height: 1),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _consoleLines.length + (isRunning ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _consoleLines.length) {
                    return AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, __) => Text(_pulse.value > 1.0 ? '█' : ' ',
                          style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'Courier', fontSize: 13)),
                    );
                  }
                  final line = _consoleLines[i];
                  final color = line.startsWith('[+]') ? const Color(0xFF00FF88)
                      : line.startsWith('[-]') ? AppTheme.error
                      : line.startsWith('[*]') ? const Color(0xFFFFBD2E)
                      : const Color(0xFF779977);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(line, style: TextStyle(color: color, fontFamily: 'Courier', fontSize: 12, height: 1.5)),
                  );
                },
              ),
            ),
          ]),
        ),
      ),

      // Result banner
      if (_phase == _Phase.done) ...[
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSuccess ? const Color(0xFF00FF88).withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSuccess ? const Color(0xFF00FF88).withOpacity(0.4) : AppTheme.error.withOpacity(0.4)),
          ),
          child: Row(children: [
            Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: isSuccess ? const Color(0xFF00FF88) : AppTheme.error, size: 30),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isSuccess ? 'تم الحقن بنجاح! ✓' : 'انتهت العملية',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: isSuccess ? const Color(0xFF00FF88) : AppTheme.error, fontFamily: 'Cairo')),
              Text(isSuccess ? 'تم إرسال event power_5w عبر AppsFlyer SDK' : 'راجع الـ console أعلاه للتفاصيل',
                  style: const TextStyle(color: Color(0xFF779977), fontFamily: 'Cairo', fontSize: 12)),
            ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('تطبيق آخر', style: TextStyle(fontFamily: 'Cairo')),
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00FF88),
                    side: const BorderSide(color: Color(0xFF00FF88)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _executeJumper(_selected!),
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('إعادة الحقن', style: TextStyle(fontFamily: 'Cairo')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF88),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ]),
        ),
      ] else
        const SizedBox(height: 16),
    ]);
  }


    // ── frida-inject not found ─────────────────────────────────────────────────
    Widget _buildFridaMissingCard() {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0000),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.error.withOpacity(0.6), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFFFBD2E), size: 22),
            SizedBox(width: 8),
            Expanded(child: Text('frida-inject غير مثبّت على الجهاز',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: Color(0xFFFFBD2E), fontFamily: 'Cairo'))),
          ]),
          const SizedBox(height: 10),
          const Divider(color: Color(0xFF330000), height: 1),
          const SizedBox(height: 10),
          _fridaStep('1', 'حمّل frida-inject من GitHub',
              'github.com/frida/frida/releases\n→ frida-inject-XX-android-x86 (محاكي)\n→ frida-inject-XX-android-arm64 (هاتف حقيقي)'),
          _fridaStep('2', 'ارفعه للجهاز',
              'adb push frida-inject /data/local/tmp/frida-inject'),
          _fridaStep('3', 'أعطه صلاحية التنفيذ',
              'adb shell su -c "chmod 755 /data/local/tmp/frida-inject"'),
          _fridaStep('4', 'أعد المحاولة', ''),
        ]),
      );
    }

    Widget _fridaStep(String n, String title, String cmd) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFFFFBD2E).withOpacity(0.15),
            border: Border.all(color: const Color(0xFFFFBD2E).withOpacity(0.5))),
          child: Center(child: Text(n, style: const TextStyle(
              color: Color(0xFFFFBD2E), fontFamily: 'Courier', fontSize: 10, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w600)),
          if (cmd.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF050D08), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2))),
              child: Text(cmd, style: const TextStyle(
                  color: Color(0xFF00FF88), fontFamily: 'Courier', fontSize: 10, height: 1.5)),
            ),
          ],
        ])),
      ]),
    );

    Widget _termDot(Color c) => Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ────────────────────────────────────────────────────────────────────────────
// App Picker Bottom Sheet
// ────────────────────────────────────────────────────────────────────────────
class _AppPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> apps;
  final void Function(Map<String, dynamic>) onSelected;
  const _AppPickerSheet({required this.apps, required this.onSelected});
  @override State<_AppPickerSheetState> createState() => _AppPickerSheetState();
}

class _AppPickerSheetState extends State<_AppPickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.apps
        .where((a) =>
            (a['name'] as String).toLowerCase().contains(_q.toLowerCase()) ||
            (a['package'] as String).toLowerCase().contains(_q.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF00FF88), width: 1)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF00FF88).withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.apps, color: Color(0xFF00FF88), size: 18),
            const SizedBox(width: 8),
            Text('اختر التطبيق (${widget.apps.length} مفتوح)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              decoration: InputDecoration(
                hintText: 'ابحث عن تطبيق...',
                hintStyle: const TextStyle(color: Color(0xFF445544), fontFamily: 'Cairo'),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00FF88), size: 20),
                filled: true, fillColor: const Color(0xFF050D08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF88), width: 0.5)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: const Color(0xFF00FF88).withOpacity(0.3), width: 0.5)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: Color(0xFF445544), fontFamily: 'Cairo')))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _AppTile(app: list[i], onTap: () => widget.onSelected(list[i])),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// App Tile — shows PID badge
// ────────────────────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final Map<String, dynamic> app;
  final VoidCallback onTap;
  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pid = app['pid'] as int? ?? -1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF050D08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.15)),
        ),
        child: Row(children: [
          _AppIcon(iconBase64: app['icon'] as String? ?? '', size: 46),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app['name'] as String? ?? '',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white, fontFamily: 'Cairo'),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(app['package'] as String? ?? '',
                style: TextStyle(color: const Color(0xFF00FF88).withOpacity(0.7), fontFamily: 'Courier', fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          // PID badge
          if (pid > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF001A0A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
              ),
              child: Text('PID\n$pid',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'Courier', fontSize: 9, height: 1.3)),
            ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF88).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt, color: Color(0xFF00FF88), size: 20),
          ),
        ]),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// App Icon Widget
// ────────────────────────────────────────────────────────────────────────────
class _AppIcon extends StatelessWidget {
  final String iconBase64;
  final double size;
  const _AppIcon({required this.iconBase64, required this.size});

  @override
  Widget build(BuildContext context) {
    if (iconBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(iconBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.memory(Uint8List.fromList(bytes), width: size, height: size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder()),
        );
      } catch (_) {}
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF001A0A),
      borderRadius: BorderRadius.circular(size * 0.22),
      border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
    ),
    child: Icon(Icons.android, color: const Color(0xFF00FF88).withOpacity(0.5), size: size * 0.55),
  );
}

// ────────────────────────────────────────────────────────────────────────────
enum _Phase { idle, loadingApps, running, done }
