import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pending = [];
  List<dynamic> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final [pendingResp, allResp] = await Future.wait([
        ApiService.get('/admin/payments/pending'),
        ApiService.get('/admin/payments'),
      ]);
      if (pendingResp['success'] == true) _pending = pendingResp['data'];
      if (allResp['success'] == true) _all = allResp['data'];
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _approve(String id) async {
    final resp = await ApiService.post('/admin/payments/$id/approve', {});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(resp['success'] == true ? 'تم قبول الدفع وتفعيل الاشتراك' : resp['message'] ?? 'فشل', style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: resp['success'] == true ? AppTheme.success : AppTheme.error,
    ));
    _loadData();
  }

  Future<void> _reject(String id) async {
    final notesCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: const Text('رفض الدفع', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textPrimary)),
        content: TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final resp = await ApiService.post('/admin/payments/$id/reject', {'adminNotes': notesCtrl.text});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(resp['success'] == true ? 'تم رفض الدفع' : 'فشل', style: const TextStyle(fontFamily: 'Cairo')),
                backgroundColor: resp['success'] == true ? AppTheme.warning : AppTheme.error,
              ));
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, minimumSize: const Size(0, 40)),
            child: const Text('رفض', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('المدفوعات ${_pending.isNotEmpty ? "(${_pending.length} معلق)" : ""}'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo'),
          tabs: [Tab(text: 'معلقة (${_pending.length})'), const Tab(text: 'الكل')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(_pending, showActions: true),
                  _buildList(_all, showActions: false),
                ],
              ),
            ),
    );
  }

  Widget _buildList(List<dynamic> items, {required bool showActions}) {
    if (items.isEmpty) return const Center(child: Text('لا توجد بيانات', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final p = items[i];
        return _buildPaymentCard(p, showActions: showActions);
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> p, {required bool showActions}) {
    final status = p['status'] as String;
    Color statusColor = status == 'APPROVED' ? AppTheme.success : status == 'REJECTED' ? AppTheme.error : AppTheme.warning;
    String statusLabel = status == 'APPROVED' ? 'مقبول' : status == 'REJECTED' ? 'مرفوض' : 'معلق';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['user']?['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo', fontSize: 13)),
                      Text('${p['plan']?['nameAr'] ?? ''} - ${_formatMethod(p['method'])}', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontFamily: 'Cairo', fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
            if (p['proofImageUrl'] != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _showProofImage(p['proofImageUrl']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, color: AppTheme.primary, size: 16),
                      SizedBox(width: 6),
                      Text('عرض صورة الإثبات', style: TextStyle(color: AppTheme.primary, fontFamily: 'Cairo', fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
            if (showActions && status == 'PENDING') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(p['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, minimumSize: const Size(0, 40)),
                      child: const Text('قبول', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(p['id']),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.error), minimumSize: const Size(0, 40)),
                      child: const Text('رفض', style: TextStyle(color: AppTheme.error, fontFamily: 'Cairo')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProofImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(title: const Text('صورة الإثبات'), backgroundColor: AppTheme.surface, elevation: 0),
            Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(32), child: Icon(Icons.broken_image, color: AppTheme.textHint, size: 64))),
          ],
        ),
      ),
    );
  }

  String _formatMethod(String method) {
    switch (method) {
      case 'SHAM_CASH': return 'Sham Cash';
      case 'SYRIATEL_CASH': return 'Syriatel Cash';
      case 'USDT_BEP20': return 'USDT BEP20';
      default: return method;
    }
  }
}
