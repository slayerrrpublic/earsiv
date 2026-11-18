import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/gib_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_utils.dart';
import 'invoice_detail_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  final AuthService authService;
  const InvoiceListScreen({super.key, required this.authService});

  @override
  State<InvoiceListScreen> createState() => InvoiceListScreenState();
}

class InvoiceListScreenState extends State<InvoiceListScreen> {
  void reload() => _loadLocal();

  final _db = DatabaseService.instance;
  List<InvoiceModel> _invoices = [];
  bool _loading = false;
  bool _syncing = false;
  String _filter = 'Tümü';

  late DateTime _syncStart;
  late DateTime _syncEnd;

  final _filters = ['Tümü', 'Taslak', 'İmzalandı', 'İptal'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _syncStart = DateTime(now.year, now.month, 1);
    _syncEnd = now;
    _loadLocal();
  }

  Future<void> _loadLocal() async {
    setState(() => _loading = true);
    final all = await _db.getAllInvoices();
    if (mounted) setState(() { _invoices = all; _loading = false; });
  }

  Future<void> _syncFromGib() async {
    if (!widget.authService.isLoggedIn) {
      _showSnack('GİB oturumu gerekli', error: true);
      return;
    }
    setState(() { _syncing = true; });

    try {
      String token = widget.authService.token!;
      final service = GibService(testMode: widget.authService.testMode);
      final startStr = AppUtils.dateTimeToGib(_syncStart);
      final endStr   = AppUtils.dateTimeToGib(_syncEnd);

      List<Map<String, dynamic>> gibList;
      try {
        gibList = await service.getInvoicesByDateRange(token, startDate: startStr, endDate: endStr);
      } on GibApiException {
        token = await widget.authService.reLogin();
        gibList = await service.getInvoicesByDateRange(token, startDate: startStr, endDate: endStr);
      }

      int added = 0, updated = 0;

      for (final raw in gibList) {
        final uuid = _str(raw['ettn']) ?? '';
        if (uuid.isEmpty) continue;

        final tarih    = _str(raw['faturaTarihi']) ?? _str(raw['belgeTarihi']) ?? AppUtils.todayGib();
        final saat     = _str(raw['faturaSaati'])  ?? '00:00:00';
        final faturaNo = _str(raw['belgeNumarasi']);
        final aliciVkn = _str(raw['aliciVknTckn']) ?? '';
        final onayDurumu = _str(raw['onayDurumu']) ?? 'Onaylanmadı';
        final toplamStr  = _str(raw['odenecekTutar']) ?? '0';
        final toplam     = double.tryParse(toplamStr.replaceAll(',', '.')) ?? 0.0;

        // Alıcı adı: ayrı alanlar veya birleşik alandan
        String aliciUnvan = _str(raw['aliciUnvan']) ?? '';
        String aliciAd    = _str(raw['aliciAdi'])   ?? '';
        String aliciSoyad = _str(raw['aliciSoyadi']) ?? '';
        final unvanAdSoyad = _str(raw['aliciUnvanAdSoyad']) ?? '';
        if (unvanAdSoyad.isNotEmpty && aliciUnvan.isEmpty && aliciAd.isEmpty) {
          if (aliciVkn.length == 10) {
            aliciUnvan = unvanAdSoyad;
          } else {
            final parts = unvanAdSoyad.trim().split(' ');
            aliciAd    = parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' ') : unvanAdSoyad;
            aliciSoyad = parts.length > 1 ? parts.last : '';
          }
        }

        // UUID ile eşleştir
        InvoiceModel? existing = await _db.getInvoiceByUuid(uuid);

        // Bulunamazsa tarih+VKN ile bul (uygulamadan kesilip UUID eşleşmeyen durumlar)
        if (existing == null && aliciVkn.isNotEmpty) {
          final locals = await _db.getAllInvoices();
          existing = locals.where((inv) =>
            _normDate(inv.tarih) == _normDate(tarih) &&
            inv.customer.vknTckn == aliciVkn &&
            inv.onayDurumu != 'Taslak'
          ).firstOrNull;
          if (existing != null) {
            await _db.updateInvoiceStatus(existing.uuid, onayDurumu, faturaNo: faturaNo);
            updated++;
            continue;
          }
        }

        if (existing != null) {
          if (existing.onayDurumu != onayDurumu) {
            await _db.updateInvoiceStatus(existing.uuid, onayDurumu, faturaNo: faturaNo);
            updated++;
          }
          continue;
        }

        // Yeni — özet kalem oluştur (GİB listesi kalem detayı vermez)
        final araTop = toplam / 1.20;
        final customer = CustomerModel(
          vknTckn: aliciVkn,
          unvan: aliciUnvan.isEmpty ? null : aliciUnvan,
          ad:    aliciAd.isEmpty    ? null : aliciAd,
          soyad: aliciSoyad.isEmpty ? null : aliciSoyad,
        );
        if (aliciVkn.isNotEmpty) await _db.saveCustomer(customer);

        await _db.saveInvoice(InvoiceModel(
          uuid: uuid,
          faturaNo: faturaNo,
          tarih: tarih,
          saat: saat,
          customer: customer,
          items: [InvoiceItem.create(
            malHizmet: "GİB'den aktarılan fatura (${faturaNo ?? uuid.substring(0, 8)})",
            miktar: 1,
            birimFiyat: araTop,
          )],
          onayDurumu: onayDurumu,
        ));
        added++;
      }

      await _loadLocal();
      if (mounted) {
        _showSnack(gibList.isEmpty
            ? "Seçili tarih aralığında GİB'de fatura bulunamadı."
            : '$added yeni fatura eklendi, $updated fatura güncellendi.');
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('GibApiException: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _syncStart, end: _syncEnd),
      locale: const Locale('tr', 'TR'),
      helpText: "GİB'den çekilecek tarih aralığı",
      saveText: 'Seç',
    );
    if (picked != null) {
      setState(() { _syncStart = picked.start; _syncEnd = picked.end; });
    }
  }

  List<InvoiceModel> get _filtered {
    List<InvoiceModel> result = _invoices;

    // Tarih aralığı filtresi — her zaman uygula
    result = result.where((inv) {
      try {
        final parts = inv.tarih.replaceAll('-', '/').split('/');
        if (parts.length != 3) return true;
        final invDate = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        return !invDate.isBefore(_syncStart) && !invDate.isAfter(_syncEnd);
      } catch (_) {
        return true;
      }
    }).toList();

    // Durum filtresi
    if (_filter != 'Tümü') {
      result = result
          .where((inv) => AppUtils.statusLabel(inv.onayDurumu) == _filter)
          .toList();
    }

    return result;
  }

  Color _statusColor(String status) {
    switch (AppUtils.statusLabel(status)) {
      case 'İmzalandı': return AppTheme.success;
      case 'Taslak':    return AppTheme.warning;
      case 'İptal':     return AppTheme.error;
      default:          return AppTheme.textSub;
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

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _normDate(String d) => d.replaceAll('-', '/');

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadLocal,
      child: Column(children: [
        // ── GİB sync paneli ────────────────────────────────────────
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            Expanded(
              child: InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.date_range, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      '${_fmtDate(_syncStart)} – ${_fmtDate(_syncEnd)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMain, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    )),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: _syncing ? null : _syncFromGib,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                icon: _syncing
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_download, size: 16),
                label: Text(_syncing ? 'Çekiliyor...' : "GİB'den Çek"),
              ),
            ),
          ]),
        ),
        // ── Filtre chips ───────────────────────────────────────────
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((f) {
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppTheme.primary.withOpacity(0.15),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.primary : AppTheme.textSub,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1),
        // ── Liste ──────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final inv = _filtered[i];
                        return _InvoiceCard(
                          invoice: inv,
                          statusColor: _statusColor(inv.onayDurumu),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => InvoiceDetailScreen(
                                invoice: inv, authService: widget.authService),
                            ));
                            _loadLocal();
                          },
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  String _fmtDate(DateTime dt) => DateFormat('dd.MM.yyyy').format(dt);

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.textSub.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(
          _filter == 'Tümü' ? 'Henüz fatura yok' : '$_filter fatura bulunamadı',
          style: const TextStyle(color: AppTheme.textSub, fontSize: 16),
        ),
        if (_filter == 'Tümü') ...[
          const SizedBox(height: 8),
          const Text(
            "Yukarıdan tarih seçip \"GİB'den Çek\" ile\neski faturalarınızı getirebilirsiniz.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSub, fontSize: 13),
          ),
        ],
      ]),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final Color statusColor;
  final VoidCallback onTap;

  const _InvoiceCard({required this.invoice, required this.statusColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(invoice.customer.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textMain),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Text(AppUtils.gibDateToDisplay(invoice.tarih),
                    style: const TextStyle(color: AppTheme.textSub, fontSize: 12)),
                if (invoice.faturaNo != null) ...[
                  const Text(' · ', style: TextStyle(color: AppTheme.textSub)),
                  Expanded(child: Text(invoice.faturaNo!,
                      style: const TextStyle(color: AppTheme.textSub, fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                ],
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(AppUtils.statusLabel(invoice.onayDurumu),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(AppUtils.formatCurrency(invoice.genelToplam),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textMain)),
              const SizedBox(height: 2),
              Text('KDV: ${AppUtils.formatCurrency(invoice.kdvTutar)}',
                  style: const TextStyle(color: AppTheme.textSub, fontSize: 11)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.textSub, size: 20),
          ]),
        ),
      ),
    );
  }
}
