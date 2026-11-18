import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/gib_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_utils.dart';
import '../utils/app_const.dart';
import '../widgets/customer_picker_widget.dart';
import 'sms_verification_screen.dart';

class NewInvoiceScreen extends StatefulWidget {
  final AuthService authService;
  final CustomerModel? initialCustomer;
  const NewInvoiceScreen({
    super.key,
    required this.authService,
    this.initialCustomer,
  });

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService.instance;
  Key _pickerKey = UniqueKey();
  int _itemsVersion = 0;
  Set<String> _uuidsBeforeSubmit = {}; // artar → _ItemRow'lar yeniden oluşturulur

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  CustomerModel? _customer;
  final List<InvoiceItem> _items = [];
  final _notlarCtrl = TextEditingController();

  bool _saving = false;
  bool _sendToGib = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _selectedTime = TimeOfDay.fromDateTime(now);
    _addItem();
    if (widget.initialCustomer != null) {
      _customer = widget.initialCustomer;
    }
  }

  @override
  void dispose() {
    _notlarCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    final item = InvoiceItem.create(malHizmet: '', miktar: 1, birimFiyat: 0);
    if (mounted) {
      setState(() => _items.add(item));
    } else {
      _items.add(item);
    }
  }

  void _addItemNoState() {
    _items.add(InvoiceItem.create(malHizmet: '', miktar: 1, birimFiyat: 0));
  }

  void _removeItem(int idx) {
    if (_items.length > 1) setState(() => _items.removeAt(idx));
  }

  void _updateItem(int idx, InvoiceItem item) {
    setState(() => _items[idx] = item);
  }

  double get _toplamTutar =>
      _items.fold(0, (s, i) => s + i.fiyat);
  double get _kdvTutar =>
      _items.fold(0, (s, i) => s + i.kdvTutar);
  double get _genelToplam => _toplamTutar + _kdvTutar;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null || _customer!.vknTckn.isEmpty) {
      _showError('Lütfen müşteri bilgilerini doldurun.');
      return;
    }
    if (_items.any((i) => i.malHizmet.isEmpty || i.birimFiyat <= 0)) {
      _showError('Lütfen tüm kalemleri eksiksiz doldurun.');
      return;
    }

    setState(() => _saving = true);

    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final invoice = InvoiceModel(
      tarih: AppUtils.dateTimeToGib(_selectedDate),
      saat: AppUtils.timeToGib(dt),
      customer: _customer!,
      items: List.from(_items),
      notlar: _notlarCtrl.text.trim().isEmpty ? null : _notlarCtrl.text.trim(),
      onayDurumu: 'Taslak',
    );

    try {
      if (_sendToGib && widget.authService.isLoggedIn) {
        // Önce GİB'e gönder — başarılıysa yerel kaydet
        await _submitToGib(invoice);
      } else {
        // Sadece yerel kaydet
        await _db.saveCustomer(_customer!);
        await _db.saveInvoice(invoice);
        _showSuccess('Fatura yerel olarak kaydedildi.');
        _reset();
      }
    } catch (e) {
      _showError(e.toString().replaceFirst('GibApiException: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submitToGib(InvoiceModel invoice) async {
    final service = GibService(testMode: widget.authService.testMode);
    String token = widget.authService.token!;

    try {
      // Göndermeden ÖNCE bugünkü listeyi çek — fark alarak yeni UUID'i bulacağız
      try {
        final beforeList = await service.getInvoicesByDateRange(
          token, startDate: invoice.tarih, endDate: invoice.tarih);
        _uuidsBeforeSubmit = beforeList
            .map((r) => r['ettn']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet();
      } catch (_) {
        _uuidsBeforeSubmit = {};
      }

      // GİB'e gönder — hata olursa yerel kayıt yapılmaz
      try {
        await service.createDraftInvoice(token, invoice);
      } on GibApiException catch (e) {
        if (e.message.contains('token') || e.message.contains('oturum')) {
          token = await widget.authService.reLogin();
          await service.createDraftInvoice(token, invoice);
        } else {
          rethrow;
        }
      }

      // GİB başarılı — farkı bul: göndermeden önce listedeki UUID'ler biliniyordu
      // Yeni UUID = sonraki listede olup öncekinde olmayan
      String gibUuid = '';
      try {
        final today = invoice.tarih;
        final afterList = await service.getInvoicesByDateRange(
          token,
          startDate: today,
          endDate: today,
        );

        // Göndermeden önce çektiğimiz listeyle farkı bul
        final newEntries = afterList.where((raw) {
          final ettn = raw['ettn']?.toString() ?? '';
          return ettn.isNotEmpty && !_uuidsBeforeSubmit.contains(ettn);
        }).toList();

        if (newEntries.isNotEmpty) {
          gibUuid = newEntries.first['ettn']?.toString() ?? '';
        }
      } catch (e) {
      }

      await _db.saveCustomer(_customer!);
      final gibInvoice = InvoiceModel(
        uuid: gibUuid.isNotEmpty ? gibUuid : invoice.uuid,
        faturaNo: invoice.faturaNo,
        tarih: invoice.tarih,
        saat: invoice.saat,
        customer: invoice.customer,
        items: invoice.items,
        notlar: invoice.notlar,
        onayDurumu: 'Onaylanmadı',
      );
      await _db.saveInvoice(gibInvoice);
      final savedUuid = gibInvoice.uuid;

      if (!mounted) return;

      // İmzalamak ister misiniz?
      final sign = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fatura GİB\'e Gönderildi'),
          content: const Text(
              'Fatura taslak olarak oluşturuldu.\nŞimdi SMS ile imzalamak ister misiniz?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Daha Sonra')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40),
              ),
              child: const Text('İmzala'),
            ),
          ],
        ),
      );

      if (sign == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SmsVerificationScreen(
              authService: widget.authService,
              invoiceUuids: [savedUuid],
            ),
          ),
        );
      }
      _showSuccess('Fatura başarıyla oluşturuldu.');
      _reset();
    } catch (e) {
      _showError(e.toString().replaceFirst('GibApiException: ', ''));
    }
  }

  void _reset() {
    _notlarCtrl.clear();
    _formKey.currentState?.reset();
    // Tüm item controller'larını önce dispose et
    setState(() {
      _items.clear();
    });
    // Sonraki frame'de yeni item ekle — controller'ların temiz initState'i garantile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _customer = null;
        _pickerKey = UniqueKey();
        _itemsVersion++;
        _addItemNoState();
        final now = DateTime.now();
        _selectedDate = now;
        _selectedTime = TimeOfDay.fromDateTime(now);
      });
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          // ── Tarih & Saat ───────────────────────────────────────
          _Section(
            title: 'Tarih & Saat',
            child: Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Tarih',
                    value: DateFormat('dd/MM/yyyy').format(_selectedDate),
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'Saat',
                    value: _selectedTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
          ),
          // ── Alıcı Bilgileri ────────────────────────────────────
          _Section(
            title: 'Alıcı Bilgileri',
            child: CustomerPickerWidget(
              key: _pickerKey,
              initial: _customer ?? widget.initialCustomer,
              token: widget.authService.token,
              testMode: widget.authService.testMode,
              onChanged: (c) => setState(() => _customer = c),
            ),
          ),
          // ── Mal / Hizmet Kalemleri ─────────────────────────────
          _Section(
            title: 'Mal / Hizmet',
            trailing: TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Kalem Ekle'),
            ),
            child: Column(
              children: [
                for (int i = 0; i < _items.length; i++)
                  _ItemRow(
                    key: ValueKey('$_itemsVersion-$i'),
                    index: i,
                    item: _items[i],
                    canRemove: _items.length > 1,
                    onChanged: (item) => _updateItem(i, item),
                    onRemove: () => _removeItem(i),
                  ),
              ],
            ),
          ),
          // ── Toplam ─────────────────────────────────────────────
          _Section(
            title: 'Özet',
            child: _TotalSummary(
              toplamTutar: _toplamTutar,
              kdvTutar: _kdvTutar,
              genelToplam: _genelToplam,
            ),
          ),
          // ── Notlar ─────────────────────────────────────────────
          _Section(
            title: 'Notlar (İsteğe Bağlı)',
            child: TextFormField(
              textCapitalization: TextCapitalization.words,
              controller: _notlarCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Fatura notu, banka bilgisi vb.',
              ),
            ),
          ),
          // ── GİB seçeneği ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: SwitchListTile(
                title: const Text('GİB\'e Gönder',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(widget.authService.isLoggedIn
                    ? 'Fatura GİB eArşiv portalına gönderilir'
                    : 'Oturum açık değil, sadece yerel kaydedilir'),
                value: _sendToGib && widget.authService.isLoggedIn,
                onChanged: widget.authService.isLoggedIn
                    ? (v) => setState(() => _sendToGib = v)
                    : null,
                activeColor: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Fatura Oluştur'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _Section(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSub,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _DateButton(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(
              label == 'Tarih' ? Icons.calendar_today : Icons.access_time,
              size: 18,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppTheme.textSub, fontSize: 11)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  final int index;
  final InvoiceItem item;
  final bool canRemove;
  final ValueChanged<InvoiceItem> onChanged;
  final VoidCallback onRemove;

  const _ItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _miktarCtrl;
  late final TextEditingController _fiyatCtrl;
  String _birim = 'ADET';
  double _kdvOrani = 20.0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.malHizmet,);
    _miktarCtrl =
        TextEditingController(text: widget.item.miktar.toStringAsFixed(0));
    _fiyatCtrl = TextEditingController(
        text: widget.item.birimFiyat > 0
            ? widget.item.birimFiyat.toStringAsFixed(2)
            : '');
    _birim = widget.item.birim;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _miktarCtrl.dispose();
    _fiyatCtrl.dispose();
    super.dispose();
  }

  void _update() {
    final miktar = double.tryParse(_miktarCtrl.text) ?? 1;
    final fiyat = double.tryParse(_fiyatCtrl.text) ?? 0;
    widget.onChanged(InvoiceItem.create(
      malHizmet: _nameCtrl.text,
      miktar: miktar,
      birim: _birim,
      birimFiyat: fiyat,
      kdvOrani: _kdvOrani,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = InvoiceItem.create(
      malHizmet: _nameCtrl.text,
      miktar: double.tryParse(_miktarCtrl.text) ?? 1,
      birim: _birim,
      birimFiyat: double.tryParse(_fiyatCtrl.text) ?? 0,
      kdvOrani: _kdvOrani,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Kalem',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.textSub)),
              const Spacer(),
              if (widget.canRemove)
                InkWell(
                  onTap: widget.onRemove,
                  child: const Icon(Icons.close,
                      size: 18, color: AppTheme.textSub),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            textCapitalization: TextCapitalization.words,
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Mal / Hizmet Adı *',
              isDense: true,
            ),
            onChanged: (_) => _update(),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextFormField(
                  controller: _miktarCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Miktar', isDense: true),
                  onChanged: (_) => _update(),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _birim,
                  decoration: const InputDecoration(
                      labelText: 'Birim', isDense: true),
                  items: AppConst.birimler
                      .map((b) => DropdownMenuItem(
                          value: b, child: Text(b, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _birim = v!);
                    _update();
                  },
                ),
              ),
              SizedBox(width: 5,),
              Expanded(
                child: DropdownButtonFormField<double>(
                  value: _kdvOrani,
                  decoration: const InputDecoration(
                    labelText: 'KDV Oranı',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('%1')),
                    DropdownMenuItem(value: 10.0, child: Text('%10')),
                    DropdownMenuItem(value: 20.0, child: Text('%20')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _kdvOrani = v);
                    _update();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _fiyatCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Birim Fiyat (₺) *',
              isDense: true,
            ),
            onChanged: (_) => _update(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Zorunlu';
              if ((double.tryParse(v) ?? 0) <= 0) return 'Geçerli fiyat girin';
              return null;
            },
          ),
          const SizedBox(height: 10),
          // KDV summary row
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AmountLabel('Ara Toplam',
                    AppUtils.formatCurrency(item.fiyat)),
                _AmountLabel(
                    'KDV %$_kdvOrani', AppUtils.formatCurrency(item.kdvTutar)),
                _AmountLabel('Toplam',
                    AppUtils.formatCurrency(item.fiyat + item.kdvTutar),
                    bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _AmountLabel(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppTheme.textSub)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.w500,
                color:
                    bold ? AppTheme.primary : AppTheme.textMain)),
      ],
    );
  }
}

class _TotalSummary extends StatelessWidget {
  final double toplamTutar;
  final double kdvTutar;
  final double genelToplam;
  const _TotalSummary({
    required this.toplamTutar,
    required this.kdvTutar,
    required this.genelToplam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _Row('Ara Toplam', AppUtils.formatCurrency(toplamTutar)),
          const Divider(height: 16),
          _Row('KDV Toplamı', AppUtils.formatCurrency(kdvTutar)),
          const Divider(height: 16),
          _Row(
            'GENEL TOPLAM',
            AppUtils.formatCurrency(genelToplam),
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final bool large;
  const _Row(this.label, this.value,
      {this.bold = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 16.0 : 14.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: size,
                fontWeight:
                    bold ? FontWeight.w700 : FontWeight.normal,
                color: bold ? AppTheme.textMain : AppTheme.textSub)),
        Text(value,
            style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color:
                    bold ? AppTheme.primary : AppTheme.textMain)),
      ],
    );
  }
}
