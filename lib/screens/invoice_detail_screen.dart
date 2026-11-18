import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/invoice_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/gib_service.dart';
import '../utils/app_theme.dart';
import '../services/pdf_service.dart';
import '../utils/app_utils.dart';
import 'sms_verification_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final InvoiceModel invoice;
  final AuthService authService;

  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    required this.authService,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _db = DatabaseService.instance;
  late InvoiceModel _invoice;
  bool _loadingHtml = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  bool get _isLocalOnly => _invoice.onayDurumu == 'Taslak';
  bool get _isGibDraft  => _invoice.onayDurumu == 'Onaylanmadı';
  bool get _canSign     => widget.authService.isLoggedIn && _isGibDraft;
  bool get _hasGibHtml  => widget.authService.isLoggedIn && !_isLocalOnly;

  bool get _isSigned {
    final s = _invoice.onayDurumu.toLowerCase()
        .replaceAll('ı', 'i').replaceAll('İ', 'i');
    return s.contains('onaylandi') && !s.contains('onaylanmadi');
  }

  // ── GİB HTML ─────────────────────────────────────────────────────────────

  Future<String?> _fetchGibHtml() async {
    setState(() => _loadingHtml = true);
    try {
      String token = widget.authService.token!;
      final service = GibService(testMode: widget.authService.testMode);
      try {
        return await service.getInvoiceHtml(token, _invoice.uuid, signed: _isSigned);
      } on GibApiException {
        token = await widget.authService.reLogin();
        return await service.getInvoiceHtml(token, _invoice.uuid, signed: _isSigned);
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('GibApiException: ', ''), error: true);
      return null;
    } finally {
      if (mounted) setState(() => _loadingHtml = false);
    }
  }

  Future<void> _viewOnGib() async {
    final html = await _fetchGibHtml();
    if (html == null || !mounted) return;
    if (html.trim().isEmpty) {
      _showSnack("GİB'den fatura içeriği alınamadı. ");
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _HtmlPreviewScreen(html: html, title: 'Fatura Görüntüle', invoice: _invoice),
    ));
  }

  Future<void> _shareGibPdf() async {
    if (!_hasGibHtml) return;
    final html = await _fetchGibHtml();
    if (html == null || !mounted) return;
    if (html.trim().isEmpty) {
      _showSnack("GİB'den fatura içeriği alınamadı. ");
      return;
    }

    try {
      await PdfService.shareHtmlPdf(html, _invoicePdfFileName(_invoice));
    } catch (e) {
      _showSnack('PDF paylaşım hatası: $e', error: true);
    }
  }

  String _invoicePdfFileName(InvoiceModel invoice) {
    return 'fatura_${invoice.faturaNo ?? invoice.uuid.substring(0, 8)}';
  }

  // ── İmzala ───────────────────────────────────────────────────────────────

  Future<void> _sign() async {
    final signed = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => SmsVerificationScreen(
        authService: widget.authService,
        invoiceUuids: [_invoice.uuid],
      ),
    ));
    if (signed == true) {
      final updated = await _db.getInvoiceByUuid(_invoice.uuid);
      if (updated != null && mounted) setState(() => _invoice = updated);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppTheme.error : AppTheme.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statusColor = _isSigned
        ? AppTheme.success
        : _invoice.onayDurumu == 'Silinmiş'
        ? AppTheme.error
        : AppTheme.warning;

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.faturaNo ?? 'Fatura Detayı'),
        actions: [
          if (_hasGibHtml)
            _loadingHtml
                ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                if (v == 'gib_view') _viewOnGib();
                if (v == 'pdf_share') _shareGibPdf();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'gib_view',
                    child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 10), Text("GİB'de Görüntüle")])),
                PopupMenuItem(value: 'pdf_share',
                    child: Row(children: [Icon(Icons.picture_as_pdf, size: 18), SizedBox(width: 10), Text('PDF Paylaş')])),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Durum bandı ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  _isSigned ? Icons.verified
                      : _invoice.onayDurumu == 'Silinmiş' ? Icons.cancel
                      : Icons.pending,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppUtils.statusLabel(_invoice.onayDurumu),
                        style: TextStyle(fontWeight: FontWeight.w700, color: statusColor, fontSize: 15)),
                    Text('${AppUtils.gibDateToDisplay(_invoice.tarih)}  ${_invoice.saat}',
                        style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(AppUtils.formatCurrency(_invoice.genelToplam),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textMain)),
                    const Text('KDV dahil', style: TextStyle(color: AppTheme.textSub, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Hızlı eylem butonları ─────────────────────────────────
          if (_hasGibHtml)
            Row(children: [
              Expanded(child: _ActionButton(
                icon: Icons.visibility, label: "GİB'de Görüntüle",
                color: AppTheme.primary, loading: _loadingHtml,
                onTap: _loadingHtml ? null : _viewOnGib,
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(
                icon: Icons.picture_as_pdf, label: 'PDF Paylaş',
                color: AppTheme.error, loading: _loadingHtml,
                onTap: _loadingHtml ? null : _shareGibPdf,
              )),
            ])
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text("Yerel fatura — GİB'e gönderilmedi, resmi geçerliliği yok.",
                    style: TextStyle(color: AppTheme.warning, fontSize: 12))),
              ]),
            ),
          const SizedBox(height: 16),

          // ── Alıcı bilgileri ───────────────────────────────────────
          _InfoCard(title: 'Alıcı Bilgileri', rows: [
            _InfoRow('VKN / TCKN', _invoice.customer.vknTckn),
            if (_invoice.customer.unvan?.isNotEmpty ?? false)
              _InfoRow('Ünvan', _invoice.customer.unvan!),
            if (_invoice.customer.ad?.isNotEmpty ?? false)
              _InfoRow('Ad', _invoice.customer.ad!),
            if (_invoice.customer.soyad?.isNotEmpty ?? false)
              _InfoRow('Soyad', _invoice.customer.soyad!),
            if (_invoice.customer.vergiDairesi?.isNotEmpty ?? false)
              _InfoRow('Vergi Dairesi', _invoice.customer.vergiDairesi!),
            if (_invoice.customer.adres?.isNotEmpty ?? false)
              _InfoRow('Cadde/Sokak', _invoice.customer.adres!),
            if ((_invoice.customer.binaNo?.isNotEmpty ?? false) ||
                (_invoice.customer.kapiNo?.isNotEmpty ?? false))
              _InfoRow('Bina/Kapı No',
                  [_invoice.customer.binaNo, _invoice.customer.kapiNo]
                      .where((s) => s?.isNotEmpty ?? false).join(' / ')),
            if (_invoice.customer.mahalle?.isNotEmpty ?? false)
              _InfoRow('Mahalle/İlçe', _invoice.customer.mahalle!),
            if (_invoice.customer.sehir?.isNotEmpty ?? false)
              _InfoRow('Şehir', _invoice.customer.sehir!),
          ]),
          const SizedBox(height: 12),

          // ── Kalemler ──────────────────────────────────────────────
          _InfoCard(
            title: 'Kalemler',
            rows: [],
            child: Column(children: [
              for (final item in _invoice.items) ...[
                _ItemDetailRow(item: item),
                if (item != _invoice.items.last) const Divider(height: 1),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Tutarlar ──────────────────────────────────────────────
          _InfoCard(title: 'Tutarlar', rows: [
            _InfoRow('Ara Toplam', AppUtils.formatCurrency(_invoice.toplamTutar)),
            _InfoRow('KDV (%20)',  AppUtils.formatCurrency(_invoice.kdvTutar)),
            _InfoRow('TOPLAM',    AppUtils.formatCurrency(_invoice.genelToplam), bold: true),
          ]),

          if (_invoice.notlar?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            _InfoCard(title: 'Notlar', rows: [_InfoRow('', _invoice.notlar!)]),
          ],

          const SizedBox(height: 24),

          if (_canSign) ...[
            ElevatedButton.icon(onPressed: _sign,
                icon: const Icon(Icons.draw), label: const Text('SMS ile İmzala')),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  const _ActionButton({required this.icon, required this.label,
    required this.color, this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(children: [
          loading
              ? SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _ItemDetailRow extends StatelessWidget {
  final InvoiceItem item;
  const _ItemDetailRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.malHizmet, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Row(children: [
          Text('${AppUtils.formatNumber(item.miktar)} ${item.birim}  ×  ${AppUtils.formatCurrency(item.birimFiyat)}',
              style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(AppUtils.formatCurrency(item.fiyat + item.kdvTutar),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('KDV: ${AppUtils.formatCurrency(item.kdvTutar)}',
                style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
          ]),
        ]),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<_InfoRow> rows;
  final Widget? child;
  const _InfoCard({required this.title, required this.rows, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppTheme.textSub, letterSpacing: 0.8)),
        ),
        const Divider(height: 1),
        if (child != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child!)
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: rows.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8), child: r)).toList(),
            ),
          ),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _InfoRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Text(value, style: const TextStyle(color: AppTheme.textSub, fontSize: 14));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110,
          child: Text(label, style: const TextStyle(color: AppTheme.textSub, fontSize: 13))),
      Expanded(child: Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
          color: bold ? AppTheme.primary : AppTheme.textMain))),
    ]);
  }
}

class _HtmlPreviewScreen extends StatefulWidget {
  final String html;
  final String title;
  final InvoiceModel invoice;

  const _HtmlPreviewScreen({
    required this.html, required this.title,
    required this.invoice,
  });

  @override
  State<_HtmlPreviewScreen> createState() => _HtmlPreviewScreenState();
}

class _HtmlPreviewScreenState extends State<_HtmlPreviewScreen> {
  late final WebViewController _controller;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.html);

  }

  Future<void> _share() async {
    await _runPdfAction(
      () => PdfService.shareHtmlPdf(widget.html, _fileName),
      'Paylaşım hatası',
    );
  }

  Future<void> _print() async {
    await _runPdfAction(
      () => PdfService.printHtmlPdf(widget.html, _fileName),
      'Yazdırma hatası',
    );
  }

  Future<void> _runPdfAction(Future<void> Function() action, String errorPrefix) async {
    setState(() => _sharing = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$errorPrefix: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String get _fileName => 'fatura_${widget.invoice.faturaNo ?? widget.invoice.uuid.substring(0, 8)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_sharing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'share') _share();
                if (value == 'print') _print();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'share',
                  child: Row(children: [Icon(Icons.share, size: 18), SizedBox(width: 10), Text('PDF Paylaş')]),
                ),
                PopupMenuItem(
                  value: 'print',
                  child: Row(children: [Icon(Icons.print, size: 18), SizedBox(width: 10), Text('PDF Yazdır')]),
                ),
              ],
            ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}


