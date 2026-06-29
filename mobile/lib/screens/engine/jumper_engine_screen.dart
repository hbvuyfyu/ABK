import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../../config/app_config.dart';

// ────────────────────────────────────────────────────────────────────────────
// MethodChannel bridge
// ────────────────────────────────────────────────────────────────────────────
class JumperBridge {
  static const _ch = MethodChannel('com.gamevent.app/jumper');

  static Future<List<Map<String, dynamic>>> getRunningApps() async {
    final raw = await _ch.invokeListMethod<Map>('getRunningApps') ?? [];
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }

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

  static Future<Map<String, dynamic>> getDeviceIds(String packageName) async {
    try {
      final raw = await _ch.invokeMapMethod<String, dynamic>(
        'getDeviceIds',
        {'packageName': packageName},
      );
      return Map<String, dynamic>.from(raw ?? {});
    } catch (_) {
      return {'gaid': '', 'afUid': ''};
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Game detect result model
// ────────────────────────────────────────────────────────────────────────────
class GameDetectResult {
  final bool found;
  final String platform;
  final String gameName;
  final String displayName;
  final String emoji;
  final String package_;
  final String devKey;
  final String appKey;
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic>? firstEvent;

  const GameDetectResult({
    required this.found,
    required this.platform,
    required this.gameName,
    required this.displayName,
    required this.emoji,
    required this.package_,
    required this.devKey,
    required this.appKey,
    required this.events,
    this.firstEvent,
  });

  factory GameDetectResult.notFound() => const GameDetectResult(
      found: false, platform: '', gameName: '', displayName: '',
      emoji: '', package_: '', devKey: '', appKey: '', events: []);
}

// ────────────────────────────────────────────────────────────────────────────
// API Service
// ────────────────────────────────────────────────────────────────────────────
class _GamesApi {
  static Future<GameDetectResult> detect(String package_) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/games/detect?package=${Uri.encodeComponent(package_)}');
    final resp = await http.get(uri, headers: {'Content-Type': 'application/json'}).timeout(
      const Duration(seconds: 15),
    );
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['found'] != true) return GameDetectResult.notFound();

    final game = data['game'] as Map<String, dynamic>? ?? {};
    final events = (data['game']?['events'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? [];
    final firstEvent = data['firstEvent'] != null
        ? Map<String, dynamic>.from(data['firstEvent'] as Map)
        : null;

    return GameDetectResult(
      found: true,
      platform: data['platform'] as String? ?? '',
      gameName: game['name'] as String? ?? '',
      displayName: game['displayName'] as String? ?? '',
      emoji: game['emoji'] as String? ?? '🎮',
      package_: game['package'] as String? ?? package_,
      devKey: game['devKey'] as String? ?? '',
      appKey: game['appKey'] as String? ?? '',
      events: events,
      firstEvent: firstEvent,
    );
  }

  static Future<Map<String, dynamic>> sendEvent({
    required String platform,
    required String package_,
    required String gaid,
    required String afUid,
    required String eventName,
    required String devKey,
    required String appKey,
    int? level,
  }) async {
    final uri = Uri.parse('${AppConfig.apiUrl}/games/send-event');
    final body = {
      'platform': platform,
      'package': package_,
      'gaid': gaid,
      'afUid': afUid,
      'eventName': eventName,
      'devKey': devKey,
      'appKey': appKey,
      if (level != null) 'level': level,
    };
    final resp = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Phases
// ────────────────────────────────────────────────────────────────────────────
enum _Phase { idle, loadingApps, detecting, extractingIds, sending, done }

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
  Map<String, dynamic>? _selectedApp;
  GameDetectResult? _detected;
  String _gaid = '';
  String _afUid = '';
  List<String> _consoleLines = [];
  bool? _success;
  String _selectedEventName = '';
  Map<String, dynamic>? _apiResult;

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

  void _log(String line) {
    if (!mounted) return;
    setState(() => _consoleLines.add(line));
  }

  void _reset() => setState(() {
    _phase = _Phase.idle;
    _selectedApp = null;
    _detected = null;
    _gaid = '';
    _afUid = '';
    _consoleLines = [];
    _success = null;
    _apiResult = null;
    _selectedEventName = '';
  });

  // ── Step 1: Get running apps ───────────────────────────────────────────────
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
        onSelected: (app) { Navigator.pop(context); _onAppSelected(app); },
      ),
    );
  }

  // ── Step 2: Detect game from backend ──────────────────────────────────────
  Future<void> _onAppSelected(Map<String, dynamic> app) async {
    setState(() {
      _selectedApp = app;
      _phase = _Phase.detecting;
      _consoleLines = [];
      _success = null;
    });

    final pkg    = app['package'] as String? ?? '';
    final name   = app['name'] as String? ?? pkg;

    _log('[*] تطبيق مختار: $name');
    _log('[*] Package: $pkg');
    _log('[*] البحث في قاعدة بيانات الألعاب...');

    try {
      final result = await _GamesApi.detect(pkg);

      if (!mounted) return;
      if (!result.found) {
        _log('[-] اللعبة غير موجودة في قاعدة البيانات');
        _log('[!] package "$pkg" غير مدعوم حالياً');
        setState(() { _success = false; _phase = _Phase.done; });
        return;
      }

      _log('[+] تم اكتشاف اللعبة: ${result.emoji} ${result.displayName}');
      _log('[+] المنصة: ${result.platform.toUpperCase()}');
      if (result.firstEvent != null) {
        _log('[+] الحدث: ${result.firstEvent!['eventName'] ?? result.firstEvent!['displayName']}');
      }

      setState(() {
        _detected = result;
        _selectedEventName = (result.firstEvent?['eventName'] as String?) ?? '';
      });

      // Step 3: Extract device IDs
      await _extractDeviceIds(pkg, result);
    } catch (e) {
      if (!mounted) return;
      _log('[-] خطأ في الكشف: $e');
      setState(() { _success = false; _phase = _Phase.done; });
    }
  }

  // ── Step 3: Extract GAID + AF UID ─────────────────────────────────────────
  Future<void> _extractDeviceIds(String pkg, GameDetectResult result) async {
    setState(() => _phase = _Phase.extractingIds);
    _log('[*] استخراج معرفات الجهاز...');

    try {
      final ids = await JumperBridge.getDeviceIds(pkg);
      if (!mounted) return;

      final gaid  = ids['gaid'] as String? ?? '';
      final afUid = ids['afUid'] as String? ?? '';

      _gaid  = gaid;
      _afUid = afUid;

      if (gaid.isNotEmpty) {
        _log('[+] GAID: ${_maskId(gaid)}');
      } else {
        _log('[!] لم يتم استخراج GAID — يرجى إدخاله يدوياً');
      }

      if (result.platform == 'af') {
        if (afUid.isNotEmpty) {
          _log('[+] AF UID: ${_maskId(afUid)}');
        } else {
          _log('[!] لم يتم استخراج AF UID من ملفات اللعبة');
        }
      }

      setState(() {});

      // If we have enough data, ask user to confirm or fill in missing data
      if (gaid.isEmpty || (result.platform == 'af' && afUid.isEmpty)) {
        _showMissingIdsDialog(result);
      } else {
        await _sendEvent(result);
      }
    } catch (e) {
      if (!mounted) return;
      _log('[-] خطأ في استخراج المعرفات: $e');
      _showMissingIdsDialog(result);
    }
  }

  void _showMissingIdsDialog(GameDetectResult result) {
    final gaidCtrl  = TextEditingController(text: _gaid);
    final afUidCtrl = TextEditingController(text: _afUid);
    final needAfUid = result.platform == 'af';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A1A0A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF00FF88), width: 1),
        ),
        title: const Text('أدخل البيانات المطلوبة',
            style: TextStyle(color: Color(0xFF00FF88), fontFamily: 'Cairo', fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'لم يتم استخراج جميع البيانات تلقائياً.\nأدخل البيانات الناقصة يدوياً:',
              style: TextStyle(color: Color(0xFF779977), fontFamily: 'Cairo', fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildDialogField(gaidCtrl, 'GAID (Google Advertising ID)',
                'مثال: 8de8604d-1318-4fd0-907c-402ea9de2529'),
            if (needAfUid) ...[
              const SizedBox(height: 12),
              _buildDialogField(afUidCtrl, 'AF UID (AppsFlyer ID)',
                  'مثال: 1777078015955-4325801374339884483'),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _reset(); },
            child: const Text('إلغاء', style: TextStyle(color: Color(0xFF779977), fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88), foregroundColor: Colors.black),
            onPressed: () {
              _gaid  = gaidCtrl.text.trim();
              _afUid = afUidCtrl.text.trim();
              Navigator.pop(context);
              if (_gaid.isEmpty) {
                _showSnack('GAID مطلوب');
                return;
              }
              if (needAfUid && _afUid.isEmpty) {
                _showSnack('AF UID مطلوب لألعاب AppsFlyer');
                return;
              }
              _sendEvent(result);
            },
            child: const Text('إرسال', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, String hint) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'Cairo', fontSize: 12)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 12),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF334433), fontFamily: 'Courier', fontSize: 11),
          filled: true, fillColor: const Color(0xFF050D08),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF00FF88), width: 0.5)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: const Color(0xFF00FF88).withOpacity(0.3), width: 0.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]);
  }

  // ── Step 4: Send event to platform via backend ─────────────────────────────
  Future<void> _sendEvent(GameDetectResult result) async {
    setState(() => _phase = _Phase.sending);
    _log('[*] إرسال الطلب إلى ${result.platform.toUpperCase()}...');
    _log('[*] GAID: ${_maskId(_gaid)}');
    if (result.platform == 'af') _log('[*] AF UID: ${_maskId(_afUid)}');
    _log('[*] الحدث: $_selectedEventName');

    try {
      final apiResult = await _GamesApi.sendEvent(
        platform: result.platform,
        package_: result.package_,
        gaid: _gaid,
        afUid: _afUid,
        eventName: _selectedEventName,
        devKey: result.devKey,
        appKey: result.appKey,
      );

      if (!mounted) return;
      _apiResult = apiResult;
      final ok = apiResult['success'] == true;
      final code = apiResult['statusCode'] ?? 0;
      final respBody = apiResult['response'] as String? ?? '';

      if (ok) {
        _log('[+] تم الإرسال بنجاح! ✓');
        _log('[+] Status: $code');
        if (respBody.isNotEmpty) _log('[+] Response: ${respBody.length > 60 ? respBody.substring(0, 60) + '...' : respBody}');
      } else {
        _log('[-] فشل الإرسال');
        _log('[-] Status: $code');
        if (respBody.isNotEmpty) _log('[-] Response: ${respBody.length > 80 ? respBody.substring(0, 80) + '...' : respBody}');
      }

      setState(() { _success = ok; _phase = _Phase.done; });
    } catch (e) {
      if (!mounted) return;
      _log('[-] خطأ في الإرسال: $e');
      setState(() { _success = false; _phase = _Phase.done; });
    }
  }

  String _maskId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}****${id.substring(id.length - 4)}';
  }

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
        _Phase.detecting   => _buildConsole(title: 'كشف اللعبة...'),
        _Phase.extractingIds => _buildConsole(title: 'استخراج البيانات...'),
        _Phase.sending     => _buildConsole(title: 'إرسال الحدث...'),
        _Phase.done        => _buildConsole(title: 'اكتمل'),
      },
    );
  }

  // ── Idle Screen ────────────────────────────────────────────────────────────
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
            child: const Center(child: Text('🦐', style: TextStyle(fontSize: 64))),
          ),
        ),
        const SizedBox(height: 28),
        const Text('محرك الجمبرة',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00FF88), fontFamily: 'Cairo', letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('07-JuMper · Smart Event Engine',
            style: TextStyle(fontSize: 12, color: Color(0xFF005500), fontFamily: 'Courier', letterSpacing: 2)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF001A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
          ),
          child: Column(children: [
            _buildStep('1', 'اختر اللعبة المفتوحة'),
            const SizedBox(height: 8),
            _buildStep('2', 'كشف تلقائي للمنصة والمعلومات'),
            const SizedBox(height: 8),
            _buildStep('3', 'استخراج GAID و AF UID تلقائياً'),
            const SizedBox(height: 8),
            _buildStep('4', 'إرسال الحدث ومشاهدة النتيجة'),
          ]),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openAppPicker,
            icon: const Text('🦐', style: TextStyle(fontSize: 22)),
            label: const Text('اضغط الجمبرة وابدأ',
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

  Widget _buildStep(String num, String text) => Row(children: [
    Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(color: Color(0xFF00FF88), shape: BoxShape.circle),
      child: Center(child: Text(num, style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold))),
    ),
    const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF88FFBB), fontFamily: 'Cairo', fontSize: 13))),
  ]);

  // ── Loading apps ───────────────────────────────────────────────────────────
  Widget _buildLoadingApps() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Transform.scale(
          scale: _pulse.value,
          child: const Text('🦐', style: TextStyle(fontSize: 72)),
        ),
      ),
      const SizedBox(height: 24),
      const Text('جاري جلب التطبيقات المفتوحة...',
          style: TextStyle(color: Color(0xFF00FF88), fontFamily: 'Cairo', fontSize: 16)),
      const SizedBox(height: 16),
      const SizedBox(width: 200,
          child: LinearProgressIndicator(color: Color(0xFF00FF88), backgroundColor: Color(0xFF001A0A))),
    ]),
  );

  // ── Console View ───────────────────────────────────────────────────────────
  Widget _buildConsole({required String title}) {
    final isRunning = _phase != _Phase.done;
    final isSuccess = _success == true;
    final detected  = _detected;

    return Column(children: [
      // Selected app + detected game header
      if (_selectedApp != null)
        _buildAppHeader(isRunning, isSuccess),

      // Detected game info card
      if (detected != null && detected.found)
        _buildGameInfoCard(detected),

      // Terminal console
      Expanded(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
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
              Text(title,
                  style: const TextStyle(color: Color(0xFF334433), fontFamily: 'Courier', fontSize: 11)),
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
                      : line.startsWith('[!]') ? const Color(0xFFFFBD2E)
                      : line.startsWith('[*]') ? const Color(0xFFAACCAA)
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
        _buildResultBanner(isSuccess),
        _buildActionButtons(isSuccess),
      ] else
        const SizedBox(height: 8),
    ]);
  }

  Widget _buildAppHeader(bool isRunning, bool isSuccess) {
    final app = _selectedApp!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF001A0A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.3)),
      ),
      child: Row(children: [
        _AppIcon(iconBase64: app['icon'] as String? ?? '', size: 40),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app['name'] as String? ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Cairo')),
          Text(app['package'] as String? ?? '',
              style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'Courier', fontSize: 10),
              overflow: TextOverflow.ellipsis),
          Text('PID: ${app['pid'] ?? "?"}',
              style: const TextStyle(color: Color(0xFF005500), fontFamily: 'Courier', fontSize: 9)),
        ])),
        const SizedBox(width: 8),
        if (isRunning)
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(width: 10, height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF00FF88).withOpacity(_pulse.value))),
          )
        else if (_phase == _Phase.done)
          Icon(_success == true ? Icons.check_circle : Icons.cancel,
              color: _success == true ? const Color(0xFF00FF88) : AppTheme.error, size: 24),
      ]),
    );
  }

  Widget _buildGameInfoCard(GameDetectResult g) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF001508),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.4)),
      ),
      child: Row(children: [
        Text(g.emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(g.displayName,
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
          Row(children: [
            _platformBadge(g.platform),
            const SizedBox(width: 8),
            if (_selectedEventName.isNotEmpty)
              Expanded(child: Text(_selectedEventName,
                  style: const TextStyle(color: Color(0xFF779977), fontFamily: 'Courier', fontSize: 10),
                  overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 20),
      ]),
    );
  }

  Widget _platformBadge(String platform) {
    final colors = {
      'af': const Color(0xFF0066CC),
      'singular': const Color(0xFF9900CC),
      'adj': const Color(0xFFCC6600),
    };
    final labels = {'af': 'AppsFlyer', 'singular': 'Singular', 'adj': 'Adjust'};
    final color = colors[platform] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(labels[platform] ?? platform,
          style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildResultBanner(bool isSuccess) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFF00FF88).withOpacity(0.1) : AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSuccess ? const Color(0xFF00FF88).withOpacity(0.4) : AppTheme.error.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: isSuccess ? const Color(0xFF00FF88) : AppTheme.error, size: 28),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isSuccess
                ? (_detected?.found == true
                    ? 'تم إرسال الحدث بنجاح عبر ${(_detected!.platform).toUpperCase()} ✓'
                    : 'لم يتم العثور على اللعبة في قاعدة البيانات')
                : 'فشل الإرسال — راجع التفاصيل أعلاه',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                color: isSuccess ? const Color(0xFF00FF88) : AppTheme.error, fontFamily: 'Cairo'),
          ),
          if (_apiResult != null && _apiResult!['statusCode'] != null)
            Text('Status Code: ${_apiResult!['statusCode']}',
                style: const TextStyle(color: Color(0xFF779977), fontFamily: 'Courier', fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _buildActionButtons(bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('تطبيق آخر', style: TextStyle(fontFamily: 'Cairo')),
            style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF00FF88),
                side: const BorderSide(color: Color(0xFF00FF88)),
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 12),
        if (isSuccess && _detected?.found == true && _detected!.events.length > 1)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showEventPicker(_detected!),
              icon: const Icon(Icons.list, size: 16),
              label: const Text('حدث آخر', style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          )
        else if (!isSuccess && _selectedApp != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () { if (_detected?.found == true) _sendEvent(_detected!); else _onAppSelected(_selectedApp!); },
              icon: const Icon(Icons.bolt, size: 16),
              label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF88),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
      ]),
    );
  }

  void _showEventPicker(GameDetectResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0A1A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF00FF88), width: 1)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF00FF88).withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('اختر الحدث', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...result.events.map((ev) {
            final evName = ev['eventName'] as String? ?? ev['displayName'] as String? ?? '';
            final display = ev['displayName'] as String? ?? evName;
            return ListTile(
              leading: const Icon(Icons.bolt, color: Color(0xFF00FF88), size: 20),
              title: Text(display, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13)),
              subtitle: Text(evName, style: const TextStyle(color: Color(0xFF779977), fontFamily: 'Courier', fontSize: 10)),
              onTap: () {
                setState(() {
                  _selectedEventName = evName;
                  _consoleLines = [];
                  _success = null;
                  _apiResult = null;
                });
                Navigator.pop(context);
                _sendEvent(result);
              },
            );
          }),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _termDot(Color c) => Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}

// ────────────────────────────────────────────────────────────────────────────
// App Picker Bottom Sheet
// ────────────────────────────────────────────────────────────────────────────
class _AppPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> apps;
  final void Function(Map<String, dynamic>) onSelected;
  const _AppPickerSheet({required this.apps, required this.onSelected});
  @override State<_AppPickerSheet> createState() => _AppPickerSheetState();
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
            const Text('🦐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('اختر اللعبة (${widget.apps.length} مفتوح)',
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
                    itemBuilder: (_, i) {
                      final app = list[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: _AppIcon(iconBase64: app['icon'] as String? ?? '', size: 44),
                        title: Text(app['name'] as String? ?? '',
                            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(app['package'] as String? ?? '',
                            style: const TextStyle(color: Color(0xFF00FF88), fontFamily: 'Courier', fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF00FF88)),
                        onTap: () => widget.onSelected(app),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
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
    if (iconBase64.isEmpty) {
      return Container(width: size, height: size,
          decoration: BoxDecoration(color: const Color(0xFF001A0A), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.gamepad, color: Color(0xFF00FF88)));
    }
    try {
      final bytes = base64Decode(iconBase64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(Uint8List.fromList(bytes), width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder()),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: const Color(0xFF001A0A), borderRadius: BorderRadius.circular(8)),
    child: const Icon(Icons.gamepad, color: Color(0xFF00FF88)),
  );
}
