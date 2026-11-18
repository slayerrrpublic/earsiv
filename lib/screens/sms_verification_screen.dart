import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/gib_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_utils.dart';

class SmsVerificationScreen extends StatefulWidget {
  final AuthService authService;
  final List<String> invoiceUuids;

  const SmsVerificationScreen({
    super.key,
    required this.authService,
    required this.invoiceUuids,
  });

  @override
  State<SmsVerificationScreen> createState() => _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends State<SmsVerificationScreen> {
  final _db = DatabaseService.instance;
  final _codeCtrl = TextEditingController();
  final _focusNode = FocusNode();

  bool _sendingSms = false;
  bool _verifying = false;
  String? _oid;
  String? _maskedPhone;
  String? _error;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    setState(() {
      _sendingSms = true;
      _error = null;
    });
    try {
      final service = GibService(testMode: widget.authService.testMode);
      final token = widget.authService.token!;

      final phone = await service.getPhoneNumber(token);
      if (phone != null) {
        setState(() => _maskedPhone = AppUtils.maskPhone(phone));
      }

      final oid = await service.startSmsVerification(token);
      if (oid == null) {
        setState(() => _error = 'SMS gönderilemedi. Portalda kayıtlı telefon numarası bulunamadı.');
        return;
      }
      setState(() => _oid = oid);
      _focusNode.requestFocus();
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('GibApiException: ', ''));
    } finally {
      if (mounted) setState(() => _sendingSms = false);
    }
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.trim().length < 4) return;
    if (_oid == null) return;

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final service = GibService(testMode: widget.authService.testMode);
      final token = widget.authService.token!;

      final ok = await service.completeSmsVerification(
        token,
        smsCode: _codeCtrl.text.trim(),
        oid: _oid!,
        uuids: widget.invoiceUuids,
      );

      if (ok) {
        // Update local db status
        for (final uuid in widget.invoiceUuids) {
          await _db.updateInvoiceStatus(uuid, 'Onaylandı');
        }
        setState(() => _success = true);
      } else {
        setState(() => _error = 'Hatalı SMS kodu. Lütfen tekrar deneyin.');
      }
    } catch (e) {
      setState(
          () => _error = e.toString().replaceFirst('GibApiException: ', ''));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SMS Doğrulama')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _success ? _buildSuccess() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sms, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SMS Doğrulaması Gerekiyor',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      _maskedPhone != null
                          ? 'GİB\'e kayıtlı $_maskedPhone numaralı telefona SMS gönderildi.'
                          : 'GİB\'e kayıtlı telefon numaranıza SMS gönderildi.',
                      style: const TextStyle(
                          color: AppTheme.textSub, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_sendingSms) ...[
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          const Center(
              child: Text('SMS gönderiliyor...',
                  style: TextStyle(color: AppTheme.textSub))),
        ] else if (_oid != null) ...[
          const SizedBox(height: 32),
          const Text('SMS Kodu',
              style:
                  TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeCtrl,
            focusNode: _focusNode,
            keyboardType: TextInputType.text,
            maxLength: 8,
            style: const TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '------',
              counterText: '',
              errorText: _error,
            ),
            onChanged: (v) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _verifying ? null : _verify,
            child: _verifying
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    '${widget.invoiceUuids.length} Faturayı İmzala'),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: _sendingSms ? null : _startVerification,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yeniden Gönder'),
            ),
          ),
        ] else if (_error != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: AppTheme.error))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _startVerification,
            child: const Text('Tekrar Dene'),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle,
                color: AppTheme.success, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            '${widget.invoiceUuids.length} Fatura İmzalandı',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain),
          ),
          const SizedBox(height: 8),
          const Text(
            'Faturalar GİB eArşiv portalında\nonaylandı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSub, fontSize: 15),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tamam'),
            ),
          ),
        ],
      ),
    );
  }
}
