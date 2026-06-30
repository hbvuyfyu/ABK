import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

// ── Phase state machine ───────────────────────────────────────────────────────
enum _Phase {
  idle,
  loadingApps,
  detecting,
  pickEvent,
  pickSchedule,
  extractingIds,
  running,
  done,
}

class JumperEngineScreen extends StatefulWidget {
  const JumperEngineScreen({super.key});
  @override
  State<JumperEngineScreen> createState() => _JumperEngineScreenState();
}

class _JumperEngineScreenState extends State<JumperEngineScreen> {
  static const _channel = MethodChannel('com.gamevent.app/jumper');

  // ── State ──────────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.idle;
  final List<String> _log = [];

  List<Map<String, dynamic>> _installedApps = [];

  Map<String, dynamic>? _detectedGame;
  String? _detectedPlatform;

  Map<String, dynamic>? _dailyUsage;

  List<Map<String, dynamic>> _gameEvents = [];
  Map<String, dynamic>? _selectedEvent;
  bool _useCustomEvent = false;
  final _customEventCtrl      = TextEditingController();
  final _customEventTokenCtrl = TextEditingController();

  bool _scheduleEnabled  = false;
  int  _scheduleCount    = 5;
  int  _scheduleInterval = 10;

  String _gaid  = '';
  String _afUid = '';
  int    _runSent  = 0;
  int    _runTotal = 0;
  Timer? _countdownTimer;
  int    _countdownSeconds = 0;
  bool   _cancelled = false;
  String _resultBanner = '';
  bool   _resultOk     = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() { super.initState(); _loadDailyUsage(); }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _customEventCtrl.dispose();
    _customEventTokenCtrl.dispose();
    super.dispose();
  }

  void _addLog(String line) {
    if (!mounted) return;
    setState(() => _log.add('[${_hhmm()}] $line'));
  }

  String _hhmm() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}:${n.second.toString().padLeft(2,'0')}';
  }

  // ── Daily usage ────────────────────────────────────────────────────────────
  Future<void> _loadDailyUsage() async {
    try {
      final res = await ApiService.get('/games/daily-usage');
      if (res['success'] == true && mounted) {
        setState(() => _dailyUsage = res['data'] as Map<String, dynamic>?);
      }
    } catch (_) {}
  }

  // ── Step 1: Load installed apps ────────────────────────────────────────────
  Future<void> _startDetection() async {
    setState(() { _phase = _Phase.loadingApps; _log.clear(); _cancelled = false; });
    _addLog('🔍 جاري تحميل قائمة التطبيقات...');

    try {
      final raw = await _channel.invokeMethod<List>('getInstalledApps') ?? [];
      final apps = raw.map<Map<String, dynamic>>((a) => Map<String, dynamic>.from(a as Map)).toList();

      if (apps.isEmpty) {
        _addLog('⚠️ لم يتم العثور على تطبيقات');
        setState(() => _phase = _Phase.idle);
        return;
      }

      setState(() => _installedApps = apps);
      _addLog('✅ تم العثور على ${apps.length} تطبيق');
      _showAppPicker();
    } catch (e) {
      _addLog('❌ خطأ: $e');
      setState(() => _phase = _Phase.idle);
    }
  }

  // ── App picker bottom sheet ────────────────────────────────────────────────
  void _showAppPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.92, minChildSize: 0.4, expand: false,
        builder: (_, scroll) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('اختر التطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
          const Divider(color: AppTheme.border, height: 20),
          Expanded(child: ListView.builder(
            controller: scroll,
            itemCount: _installedApps.length,
            itemBuilder: (_, i) {
              final app = _installedApps[i];
              return ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.gamepad_outlined, color: AppTheme.primary, size: 22),
                ),
                title: Text(app['label'] ?? app['package'] ?? '', style: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary, fontSize: 14)),
                subtitle: Text(app['package'] ?? '', style: const TextStyle(color: AppTheme.textHint, fontSize: 10, fontFamily: 'monospace')),
                onTap: () { Navigator.pop(context); _detectGame(app['package'] ?? ''); },
              );
            },
          )),
        ]),
      ),
    ).whenComplete(() {
      if (_phase == _Phase.loadingApps && mounted) setState(() => _phase = _Phase.idle);
    });
  }

  // ── Step 3: Detect ─────────────────────────────────────────────────────────
  Future<void> _detectGame(String pkg) async {
    setState(() => _phase = _Phase.detecting);
    _addLog('🎮 فحص "$pkg"...');

    try {
      final res = await ApiService.get('/games/detect?package=${Uri.encodeComponent(pkg)}', auth: false);
      if (res['found'] == true) {
        final game   = res['game'] as Map<String, dynamic>;
        final events = (game['events'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _addLog('✅ تم الكشف: ${game['displayName']} [${res['platform']}]');
        _addLog('📋 أحداث متاحة: ${events.length}');
        if (!mounted) return;
        setState(() {
          _detectedGame    = game;
          _detectedPlatform = res['platform'] as String?;
          _gameEvents      = events;
          _selectedEvent   = events.isNotEmpty ? events.first : null;
          _useCustomEvent  = false;
          _phase           = _Phase.pickEvent;
        });
      } else {
        _addLog('⚠️ هذه اللعبة غير مدعومة');
        setState(() => _phase = _Phase.idle);
      }
    } catch (e) {
      _addLog('❌ خطأ اتصال: $e');
      setState(() => _phase = _Phase.idle);
    }
  }

  // ── Step 5: Extract IDs ────────────────────────────────────────────────────
  Future<void> _startExtractionAndSend() async {
    setState(() { _phase = _Phase.extractingIds; _runSent = 0; _runTotal = _scheduleEnabled ? _scheduleCount : 1; });
    _addLog('📡 استخراج معرفات الجهاز...');

    try {
      final ids = await _channel.invokeMethod<Map>('getDeviceIds') ?? {};
      _gaid  = ids['gaid']?.toString()  ?? '';
      _afUid = ids['afUid']?.toString() ?? '';

      if (_gaid.isEmpty) {
        _addLog('⚠️ فشل الحصول على GAID — تأكد من صلاحيات الجذر');
        setState(() => _phase = _Phase.idle);
        return;
      }
      _addLog('✅ GAID: ${_gaid.substring(0, _gaid.length.clamp(0, 8))}...');
      if (_afUid.isNotEmpty) _addLog('✅ AF UID: ${_afUid.substring(0, _afUid.length.clamp(0, 8))}...');

      setState(() => _phase = _Phase.running);
      await _sendNext();
    } catch (e) {
      _addLog('❌ خطأ استخراج IDs: $e');
      setState(() => _phase = _Phase.idle);
    }
  }

  // ── Send cycle ─────────────────────────────────────────────────────────────
  Future<void> _sendNext() async {
    if (_cancelled || !mounted) return;
    _addLog('🚀 إرسال الحدث (${_runSent + 1}/$_runTotal)...');
    final ok = await _doSendEvent();

    if (ok && mounted) { setState(() => _runSent++); await _loadDailyUsage(); }

    if (_cancelled || !ok || _runSent >= _runTotal) { _finishRun(ok); return; }

    final delaySecs = _scheduleInterval * 60;
    _addLog('⏳ الإرسال التالي بعد $_scheduleInterval دقيقة...');
    if (!mounted) return;
    setState(() => _countdownSeconds = delaySecs);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _cancelled) { t.cancel(); return; }
      setState(() { _countdownSeconds--; });
      if (_countdownSeconds <= 0) { t.cancel(); _sendNext(); }
    });
  }

  Future<bool> _doSendEvent() async {
    final game     = _detectedGame!;
    final platform = _detectedPlatform!;
    String eventName  = '';
    String eventToken = '';

    if (_useCustomEvent) {
      eventName  = _customEventCtrl.text.trim();
      eventToken = _customEventTokenCtrl.text.trim();
    } else if (_selectedEvent != null) {
      eventName  = _selectedEvent!['eventName']  as String? ?? '';
      eventToken = _selectedEvent!['eventToken'] as String? ?? '';
    }

    if (eventName.isEmpty && eventToken.isEmpty) { _addLog('⚠️ لم يتم اختيار حدث'); return false; }

    final body = <String, dynamic>{ 'platform': platform, 'gaid': _gaid };
    if (_afUid.isNotEmpty) body['afUid'] = _afUid;

    switch (platform) {
      case 'af':
        body['package']   = game['package'];
        body['devKey']    = game['devKey'];
        body['eventName'] = eventName;
      case 'adj':
        body['appToken']   = game['appToken'];
        body['eventToken'] = eventToken.isNotEmpty ? eventToken : eventName;
      case 'singular':
        body['package']   = game['package'];
        body['appKey']    = game['appKey'];
        body['eventName'] = eventName;
    }

    try {
      final res = await ApiService.post('/games/send-event', body);
      final sc  = res['_statusCode'] as int? ?? 0;

      if (sc == 403 || sc == 401) {
        final code = res['code'] as String? ?? '';
        if (code == 'NO_SUBSCRIPTION') {
          _addLog('🔒 لا يوجد اشتراك نشط. اشترك في باقة أولاً.');
        } else if (code == 'DAILY_LIMIT_EXCEEDED') {
          final limit = res['limit'] ?? 0;
          _addLog('⛔ وصلت للحد اليومي ($limit عملية). حاول غداً.');
        } else {
          _addLog('🔒 خطأ مصادقة. يرجى إعادة تسجيل الدخول.');
        }
        if (mounted) setState(() => _cancelled = true);
        return false;
      }

      if (res['success'] == true) {
        final sent      = res['eventName'] as String? ?? eventName;
        final usage     = res['dailyUsage'] as Map<String, dynamic>?;
        final remaining = usage?['remaining'] ?? '—';
        _addLog('✅ "$sent" ← HTTP ${res['statusCode']}');
        _addLog('📊 عمليات متبقية اليوم: $remaining');
        return true;
      }

      _addLog('❌ فشل: ${res['message'] ?? 'خطأ'}');
      return false;
    } catch (e) {
      _addLog('❌ خطأ شبكة: $e');
      return false;
    }
  }

  void _finishRun(bool _) {
    _countdownTimer?.cancel();
    final ok = _runSent > 0;
    if (!mounted) return;
    setState(() {
      _phase        = _Phase.done;
      _resultOk     = ok;
      _resultBanner = ok ? '✅ تم إرسال $_runSent/$_runTotal حدث بنجاح!' : '❌ فشل الإرسال';
    });
    _addLog(_resultBanner);
    _loadDailyUsage();
  }

  void _cancelSchedule() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() => _cancelled = true);
    _addLog('🛑 تم إيقاف الجدولة');
    _finishRun(false);
  }

  void _reset() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _phase           = _Phase.idle;
      _log.clear();
      _detectedGame    = null;
      _detectedPlatform = null;
      _gameEvents      = [];
      _selectedEvent   = null;
      _useCustomEvent  = false;
      _scheduleEnabled = false;
      _runSent  = 0; _runTotal = 0;
      _countdownSeconds = 0;
      _cancelled = false;
    });
    _loadDailyUsage();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        elevation: 0,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt, color: AppTheme.primary, size: 20),
          SizedBox(width: 8),
          Text('محرك الأحداث', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary)),
        ]),
      ),
      body: Column(children: [
        if (_dailyUsage != null) _buildUsageBar(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildPhaseUI(),
            const SizedBox(height: 20),
            if (_log.isNotEmpty) _buildTerminal(),
          ]),
        )),
      ]),
    );
  }

  Widget _buildPhaseUI() {
    switch (_phase) {
      case _Phase.idle:
      case _Phase.loadingApps:
        return _buildIdleCard();
      case _Phase.detecting:
        return _buildSpinnerCard('🔍 جاري البحث في قاعدة الألعاب...', 'يتم التحقق من جميع المنصات المتاحة');
      case _Phase.pickEvent:
        return _buildEventPickerCard();
      case _Phase.pickSchedule:
        return _buildScheduleCard();
      case _Phase.extractingIds:
        return _buildSpinnerCard('📡 استخراج معرفات الجهاز...', 'يتطلب صلاحيات الجذر (Root)');
      case _Phase.running:
        return _buildRunningCard();
      case _Phase.done:
        return _buildDoneCard();
    }
  }

  // ── Daily usage bar ────────────────────────────────────────────────────────
  Widget _buildUsageBar() {
    final d = _dailyUsage!;
    if (d['hasSubscription'] != true) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error.withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.warning_amber_outlined, color: AppTheme.error, size: 16),
          SizedBox(width: 8),
          Text('لا يوجد اشتراك نشط — يرجى الاشتراك في باقة', style: TextStyle(color: AppTheme.error, fontFamily: 'Cairo', fontSize: 12)),
        ]),
      );
    }
    final used      = (d['used']      as num?)?.toInt() ?? 0;
    final limit     = (d['limit']     as num?)?.toInt() ?? 1;
    final remaining = (d['remaining'] as num?)?.toInt() ?? 0;
    final progress  = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final barColor  = remaining == 0 ? AppTheme.error : remaining < (limit * 0.2) ? AppTheme.warning : AppTheme.success;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.bolt, color: barColor, size: 15),
          const SizedBox(width: 6),
          Text(d['planName']?.toString() ?? 'باقتك', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
          const Spacer(),
          Text('$used / $limit عملية', style: TextStyle(color: barColor, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: progress, backgroundColor: AppTheme.border, valueColor: AlwaysStoppedAnimation(barColor), minHeight: 5)),
      ]),
    );
  }

  // ── Idle card ──────────────────────────────────────────────────────────────
  Widget _buildIdleCard() {
    final isLoading = _phase == _Phase.loadingApps;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.cardBg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primary.withOpacity(0.15), border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2)),
          child: isLoading
              ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5))
              : const Icon(Icons.search_rounded, color: AppTheme.primary, size: 34),
        ),
        const SizedBox(height: 18),
        Text(isLoading ? 'جاري تحميل التطبيقات...' : 'اكتشاف اللعبة تلقائياً',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 8),
        const Text('سيتم فحص التطبيقات المثبتة، تحديد اللعبة،\nاستخراج GAID وإرسال الحدث المختار',
            textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 13, height: 1.6)),
        const SizedBox(height: 22),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: isLoading ? null : _startDetection,
          icon: isLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.play_circle_outline),
          label: Text(isLoading ? 'جاري التحميل...' : '🚀 ابدأ الاكتشاف',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary, disabledBackgroundColor: AppTheme.primary.withOpacity(0.4),
            foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
      ]),
    );
  }

  // ── Spinner card ───────────────────────────────────────────────────────────
  Widget _buildSpinnerCard(String title, String sub) => Container(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border)),
    child: Column(children: [
      const CircularProgressIndicator(color: AppTheme.primary),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 6),
      Text(sub, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
    ]),
  );

  // ── Event picker ───────────────────────────────────────────────────────────
  Widget _buildEventPickerCard() {
    final game     = _detectedGame!;
    final platform = _detectedPlatform ?? '';
    final pLabels  = {'af': 'AppsFlyer', 'singular': 'Singular', 'adj': 'Adjust'};
    final pColors  = {'af': const Color(0xFF0077CC), 'singular': const Color(0xFF9900CC), 'adj': const Color(0xFFCC6600)};
    final pColor   = pColors[platform] ?? AppTheme.primary;

    return Column(children: [
      // Game info banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.success.withOpacity(0.35))),
        child: Row(children: [
          Text(game['emoji'] ?? '🎮', style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(game['displayName'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, children: [
              _badge(pLabels[platform] ?? platform, pColor),
              _badge('✅ تم الكشف', AppTheme.success),
            ]),
          ])),
        ]),
      ),
      const SizedBox(height: 14),

      // Events
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.bolt, color: AppTheme.accent, size: 17),
            SizedBox(width: 8),
            Text('اختر الحدث', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15)),
          ]),
          const SizedBox(height: 12),

          ..._gameEvents.map((ev) {
            final sel = !_useCustomEvent && _selectedEvent == ev;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() { _selectedEvent = ev; _useCustomEvent = false; }),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Row(children: [
                    Icon(ev['isPurchase'] == true ? Icons.shopping_cart_outlined : Icons.videogame_asset_outlined,
                        color: sel ? AppTheme.primary : AppTheme.textSecondary, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ev['displayName'] ?? '', style: TextStyle(color: sel ? AppTheme.primary : AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(ev['eventName'] ?? ev['eventToken'] ?? '', style: const TextStyle(color: AppTheme.textHint, fontFamily: 'monospace', fontSize: 10)),
                    ])),
                    if (ev['isPurchase'] == true) _badge('شراء', AppTheme.warning),
                    const SizedBox(width: 6),
                    if (sel) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 18),
                  ]),
                ),
              ),
            );
          }),

          // Custom event
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(color: AppTheme.border)),
          InkWell(
            onTap: () => setState(() => _useCustomEvent = !_useCustomEvent),
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _useCustomEvent ? AppTheme.accent.withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _useCustomEvent ? AppTheme.accent : AppTheme.border.withOpacity(0.6)),
              ),
              child: Row(children: [
                const Icon(Icons.edit_outlined, color: AppTheme.accent, size: 18),
                const SizedBox(width: 10),
                const Expanded(child: Text('✏️ حدث مخصص (Custom)', style: TextStyle(color: AppTheme.accent, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13))),
                Icon(_useCustomEvent ? Icons.expand_less : Icons.expand_more, color: AppTheme.accent),
              ]),
            ),
          ),

          if (_useCustomEvent) Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(children: [
              _inputField(_customEventCtrl, 'اسم الحدث (eventName)', 'my_custom_event'),
              if (platform == 'adj') ...[
                const SizedBox(height: 10),
                _inputField(_customEventTokenCtrl, 'Event Token (Adjust)', 'abc123xyz'),
              ],
            ]),
          ),

          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: (_useCustomEvent && _customEventCtrl.text.trim().isEmpty)
                ? null
                : () => setState(() => _phase = _Phase.pickSchedule),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary, disabledBackgroundColor: AppTheme.border,
              foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('التالي: إعداد الجدولة ←', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
          )),
        ]),
      ),
    ]);
  }

  // ── Schedule card ──────────────────────────────────────────────────────────
  Widget _buildScheduleCard() {
    final eventLabel = _useCustomEvent ? _customEventCtrl.text : (_selectedEvent?['displayName'] ?? '');
    return Column(children: [
      // Summary header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Text(_detectedGame?['emoji'] ?? '🎮', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_detectedGame?['displayName'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 14)),
            Text(eventLabel, style: const TextStyle(color: AppTheme.accent, fontFamily: 'Cairo', fontSize: 12)),
          ])),
          TextButton(
            onPressed: () => setState(() => _phase = _Phase.pickEvent),
            child: const Text('← تغيير', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppTheme.textSecondary)),
          ),
        ]),
      ),
      const SizedBox(height: 14),

      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.schedule_outlined, color: AppTheme.primary, size: 17),
            SizedBox(width: 8),
            Text('إعدادات الجدولة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 15)),
          ]),
          const SizedBox(height: 16),

          // Mode selector
          Row(children: [
            Expanded(child: _modeCard(Icons.send_rounded,    'إرسال فوري',      'مرة واحدة الآن', !_scheduleEnabled, () => setState(() => _scheduleEnabled = false))),
            const SizedBox(width: 10),
            Expanded(child: _modeCard(Icons.repeat_outlined, 'جدولة متكررة',    'أكثر من مرة',     _scheduleEnabled, () => setState(() => _scheduleEnabled = true))),
          ]),

          if (_scheduleEnabled) ...[
            const SizedBox(height: 20),
            const Text('عدد مرات الإرسال', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              _stepBtn(Icons.remove, () => setState(() { if (_scheduleCount > 1) _scheduleCount--; })),
              const SizedBox(width: 14),
              Text('$_scheduleCount مرة', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 18)),
              const SizedBox(width: 14),
              _stepBtn(Icons.add, () => setState(() { if (_scheduleCount < 100) _scheduleCount++; })),
              const Spacer(),
              for (final n in [5, 10, 20, 50]) _quickPick(n, _scheduleCount, (v) => setState(() => _scheduleCount = v), AppTheme.primary),
            ]),

            const SizedBox(height: 16),
            const Text('الفاصل الزمني (دقائق)', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              _stepBtn(Icons.remove, () => setState(() { if (_scheduleInterval > 1) _scheduleInterval--; })),
              const SizedBox(width: 14),
              Text('$_scheduleInterval د', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 18)),
              const SizedBox(width: 14),
              _stepBtn(Icons.add, () => setState(() { if (_scheduleInterval < 60) _scheduleInterval++; })),
              const Spacer(),
              for (final n in [5, 10, 15, 30]) _quickPick(n, _scheduleInterval, (v) => setState(() => _scheduleInterval = v), AppTheme.accent),
            ]),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.07), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppTheme.primary, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '$_scheduleCount إرسال × كل $_scheduleInterval دقيقة = مدة إجمالية: ${(_scheduleCount - 1) * _scheduleInterval} دقيقة',
                  style: const TextStyle(color: AppTheme.primary, fontFamily: 'Cairo', fontSize: 11),
                )),
              ]),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _startExtractionAndSend,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: Text(_scheduleEnabled ? '🚀 بدء الجدولة' : '🚀 إرسال الآن',
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
        ]),
      ),
    ]);
  }

  // ── Running card ───────────────────────────────────────────────────────────
  Widget _buildRunningCard() {
    final progress     = _runTotal > 0 ? (_runSent / _runTotal).clamp(0.0, 1.0) : 0.0;
    final hasCountdown = _countdownSeconds > 0 && _scheduleEnabled && _runSent < _runTotal;
    final mins = _countdownSeconds ~/ 60;
    final secs = _countdownSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.35))),
      child: Column(children: [
        SizedBox(
          width: 100, height: 100,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: progress, color: AppTheme.primary, backgroundColor: AppTheme.border, strokeWidth: 7),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$_runSent', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
              Text('/ $_runTotal', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'Cairo')),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        Text(_scheduleEnabled ? '🕐 جدولة نشطة...' : '🚀 جاري الإرسال...',
            style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
        if (hasCountdown) ...[
          const SizedBox(height: 8),
          Text('الإرسال التالي: ${mins.toString().padLeft(2,'0')}:${secs.toString().padLeft(2,'0')}',
              style: const TextStyle(color: AppTheme.accent, fontFamily: 'Cairo', fontSize: 14)),
        ],
        if (_scheduleEnabled && _runSent < _runTotal) ...[
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: _cancelSchedule,
            icon: const Icon(Icons.stop_circle_outlined, color: AppTheme.error, size: 18),
            label: const Text('إيقاف الجدولة', style: TextStyle(color: AppTheme.error, fontFamily: 'Cairo')),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          )),
        ],
      ]),
    );
  }

  // ── Done card ──────────────────────────────────────────────────────────────
  Widget _buildDoneCard() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: _resultOk ? AppTheme.success.withOpacity(0.07) : AppTheme.error.withOpacity(0.07),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _resultOk ? AppTheme.success.withOpacity(0.4) : AppTheme.error.withOpacity(0.4)),
    ),
    child: Column(children: [
      Icon(_resultOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: _resultOk ? AppTheme.success : AppTheme.error, size: 60),
      const SizedBox(height: 12),
      Text(_resultBanner, textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _resultOk ? AppTheme.success : AppTheme.error, fontFamily: 'Cairo')),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _reset,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('بدء من جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]),
  );

  // ── Terminal ───────────────────────────────────────────────────────────────
  Widget _buildTerminal() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF30363D))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Row(children: [
          _Dot(c: Color(0xFFFF5F56)), SizedBox(width: 5),
          _Dot(c: Color(0xFFFFBD2E)), SizedBox(width: 5),
          _Dot(c: Color(0xFF27C93F)),
        ]),
        const SizedBox(width: 10),
        const Expanded(child: Text('Terminal', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11))),
        GestureDetector(onTap: () => setState(() => _log.clear()), child: const Text('مسح ✕', style: TextStyle(color: Color(0xFF8B949E), fontSize: 11))),
      ]),
      const SizedBox(height: 10),
      ..._log.map((line) {
        final c = line.contains('✅') || line.contains('🚀') ? const Color(0xFF3FB950)
            : line.contains('❌') || line.contains('⛔') ? const Color(0xFFF85149)
            : line.contains('⚠️') || line.contains('🔒') ? const Color(0xFFD29922)
            : line.contains('📊') || line.contains('📡') ? const Color(0xFF58A6FF)
            : const Color(0xFFE6EDF3);
        return Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(line, style: TextStyle(color: c, fontFamily: 'monospace', fontSize: 10.5, height: 1.4)));
      }),
    ]),
  );

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  Widget _modeCard(IconData icon, String label, String sub, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: sel ? AppTheme.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? AppTheme.primary : AppTheme.border, width: sel ? 1.5 : 1),
      ),
      child: Column(children: [
        Icon(icon, color: sel ? AppTheme.primary : AppTheme.textHint, size: 22),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: sel ? AppTheme.primary : AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
        Text(sub, style: const TextStyle(color: AppTheme.textHint, fontFamily: 'Cairo', fontSize: 10), textAlign: TextAlign.center),
      ]),
    ),
  );

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppTheme.textPrimary, size: 16),
    ),
  );

  Widget _quickPick(int value, int current, ValueChanged<int> onSelect, Color color) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: current == value ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: current == value ? color : AppTheme.border),
        ),
        child: Text('$value', style: TextStyle(color: current == value ? color : AppTheme.textHint, fontSize: 11, fontFamily: 'Cairo')),
      ),
    ),
  );

  Widget _inputField(TextEditingController ctrl, String label, String hint) => TextField(
    controller: ctrl,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace', fontSize: 13),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(fontFamily: 'Cairo', color: AppTheme.textSecondary, fontSize: 12),
      hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 11),
    ),
  );
}

class _Dot extends StatelessWidget {
  final Color c;
  const _Dot({required this.c});
  @override
  Widget build(BuildContext ctx) => Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
