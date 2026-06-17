import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class PaymentProofScreen extends StatefulWidget {
  final String paymentId;
  const PaymentProofScreen({super.key, required this.paymentId});

  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  Map<String, dynamic>? _settings;
  bool _loading = true;
  XFile? _image;
  bool _uploading = false;
  String? _method;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final resp = await ApiService.get('/settings/payment', auth: false);
      if (resp['success'] == true) setState(() => _settings = resp['data']);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _image = img);
  }

  Future<void> _submit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('يرجى رفع صورة إثبات الدفع', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppTheme.warning,
      ));
      return;
    }
    setState(() => _uploading = true);
    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final resp = await ApiService.post('/payments/${widget.paymentId}/proof', {'imageBase64': base64Image});
      if (!mounted) return;
      if (resp['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم رفع إثبات الدفع بنجاح. سيتم مراجعته من قبل الأدمن', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppTheme.success,
        ));
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resp['message'] ?? 'فشل في رفع الصورة', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppTheme.error,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('خطأ في الاتصال', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppTheme.error,
      ));
    }
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الدفع'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInstructions(),
                  const SizedBox(height: 24),
                  _buildImagePicker(),
                  const SizedBox(height: 24),
                  GradientButton(onPressed: _uploading ? null : _submit, isLoading: _uploading, text: 'تأكيد الدفع وإرسال للمراجعة'),
                ],
              ),
            ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primary, size: 22),
              SizedBox(width: 8),
              Text('تعليمات الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(height: 16),
          if (_settings != null) ...[
            _buildAddressRow('Sham Cash', _settings!['sham_cash_address'] ?? '', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 12),
            _buildAddressRow('Syriatel Cash', _settings!['syriatel_cash_address'] ?? '', Icons.phone_android_outlined),
          ],
          const SizedBox(height: 16),
          Text(_settings?['sham_cash_instructions'] ?? 'قم بإرسال المبلغ ثم ارفع صورة الإيصال',
            style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildAddressRow(String label, String address, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
            Text(address, style: const TextStyle(color: AppTheme.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.copy, color: AppTheme.textHint, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: address));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ', style: TextStyle(fontFamily: 'Cairo')), duration: Duration(seconds: 1)));
          },
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('صورة إثبات الدفع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _image != null ? AppTheme.success : AppTheme.border, width: 2, style: BorderStyle.solid),
            ),
            child: _image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FutureBuilder<Uint8List>(
                      future: _image!.readAsBytes(),
                      builder: (_, snap) => snap.hasData
                          ? Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity)
                          : const Center(child: CircularProgressIndicator()),
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary, size: 48),
                      SizedBox(height: 8),
                      Text('اضغط لرفع صورة الإيصال', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
