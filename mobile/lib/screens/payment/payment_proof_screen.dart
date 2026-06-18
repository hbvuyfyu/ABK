import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';

class PaymentProofScreen extends StatefulWidget {
  final String paymentId;
  const PaymentProofScreen({super.key, required this.paymentId});
  @override
  State<PaymentProofScreen> createState() => _PaymentProofScreenState();
}

class _PaymentProofScreenState extends State<PaymentProofScreen> {
  Map<String, dynamic>? _payment;
  Map<String, dynamic>? _settings;
  bool _loading = true;
  XFile? _pickedImage;
  bool _submitting = false;

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    try {
      final db = Supabase.instance.client;
      final results = await Future.wait([
        db.from('payments').select('*, plans(name,price)').eq('id', widget.paymentId).maybeSingle(),
        db.from('settings').select(),
      ]);
      _payment = results[0] as Map<String, dynamic>?;
      final settingsList = results[1] as List;
      _settings = {for (final s in settingsList) s['key']: s['value']};
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<void> _submit() async {
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إرفاق صورة الإثبات', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.warning));
      return;
    }
    setState(() => _submitting = true);
    try {
      final bytes = await _pickedImage!.readAsBytes();
      final b64 = base64Encode(bytes);
      await Supabase.instance.client.from('payments').update({'proof_image': b64}).eq('id', widget.paymentId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإثبات، انتظر موافقة الأدمن', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.success));
      context.go('/');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الإرسال', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppTheme.error));
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final method = _payment?['method'] as String? ?? '';
    final address = method == 'SHAM_CASH' ? (_settings?['sham_cash_number'] ?? '') : (_settings?['syriatel_cash_number'] ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('إرسال إثبات الدفع'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => context.pop())),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_payment?['plans']?['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                Text('المبلغ: \$${_payment?['amount'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('الرقم: $address', style: const TextStyle(color: AppTheme.accent, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ],
              ])),
              const SizedBox(height: 24),
              const Text('صورة الإثبات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontFamily: 'Cairo')),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 180, width: double.infinity,
                  decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border, style: BorderStyle.solid)),
                  child: _pickedImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(_pickedImage!.path, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: AppTheme.primary, size: 48)))
                      : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primary, size: 48),
                          SizedBox(height: 8),
                          Text('اضغط لاختيار صورة', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'Cairo')),
                        ]),
                ),
              ),
              const SizedBox(height: 32),
              GradientButton(onPressed: _submitting ? null : _submit, isLoading: _submitting, text: 'إرسال الإثبات'),
            ])),
    );
  }
}