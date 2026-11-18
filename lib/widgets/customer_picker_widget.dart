import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/customer_model.dart';
import '../services/database_service.dart';
import '../services/gib_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_utils.dart';

class CustomerPickerWidget extends StatefulWidget {
  final CustomerModel? initial;
  final String? token;
  final bool testMode;
  final ValueChanged<CustomerModel?> onChanged;

  const CustomerPickerWidget({
    super.key,
    this.initial,
    this.token,
    this.testMode = false,
    required this.onChanged,
  });

  @override
  State<CustomerPickerWidget> createState() => _CustomerPickerWidgetState();
}

class _CustomerPickerWidgetState extends State<CustomerPickerWidget> {
  final _db = DatabaseService.instance;

  final _vknCtrl = TextEditingController();
  final _unvanCtrl = TextEditingController();
  final _adCtrl = TextEditingController();
  final _soyadCtrl = TextEditingController();
  final _vergiDairesiCtrl = TextEditingController();
  final _adresCtrl = TextEditingController();
  final _mahalleCtrl = TextEditingController();
  final _sehirCtrl = TextEditingController();
  final _binaNoCtrl = TextEditingController();
  final _kapiNoCtrl = TextEditingController();

  final _vknFocus = FocusNode();
  final _unvanFocus = FocusNode();
  final _adFocus = FocusNode();
  final _soyadFocus = FocusNode();
  final _vergiDairesiFocus = FocusNode();
  final _adresFocus = FocusNode();
  final _binaNoFocus = FocusNode();
  final _kapiNoFocus = FocusNode();
  final _mahalleFocus = FocusNode();
  final _sehirFocus = FocusNode();

  bool _querying = false;
  String? _queryError;
  bool _lockAdSoyad = false;
  bool _lockUnvan = false;

  List<CustomerModel> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) _fill(widget.initial!);

    _vknFocus.addListener(() {
      if (!_vknFocus.hasFocus) {
        final v = _vknCtrl.text.trim();
        if (v.isEmpty) return;
        if (!AppUtils.isValidVknOrTckn(v)) {
          setState(() => _queryError = 'Geçerli VKN (10) veya TCKN (11) girin');
          return;
        }
        if (widget.testMode) return;
        _queryGib(v);
      }
    });
  }

  @override
  void dispose() {
    _vknCtrl.dispose();
    _unvanCtrl.dispose();
    _adCtrl.dispose();
    _soyadCtrl.dispose();
    _vergiDairesiCtrl.dispose();
    _adresCtrl.dispose();
    _mahalleCtrl.dispose();
    _sehirCtrl.dispose();
    _binaNoCtrl.dispose();
    _kapiNoCtrl.dispose();
    _vknFocus.dispose();
    _unvanFocus.dispose();
    _adFocus.dispose();
    _soyadFocus.dispose();
    _vergiDairesiFocus.dispose();
    _adresFocus.dispose();
    _binaNoFocus.dispose();
    _kapiNoFocus.dispose();
    _mahalleFocus.dispose();
    _sehirFocus.dispose();
    super.dispose();
  }

  void _fill(CustomerModel c) {
    _vknCtrl.text = c.vknTckn;
    _unvanCtrl.text = c.unvan ?? '';
    _adCtrl.text = c.ad ?? '';
    _soyadCtrl.text = c.soyad ?? '';
    _vergiDairesiCtrl.text = c.vergiDairesi ?? '';
    _adresCtrl.text = c.adres ?? '';
    _mahalleCtrl.text = c.mahalle ?? '';
    _sehirCtrl.text = c.sehir ?? '';
    _binaNoCtrl.text = c.binaNo ?? '';
    _kapiNoCtrl.text = c.kapiNo ?? '';
  }

  void _clearAll() {
    _vknCtrl.clear();
    _unvanCtrl.clear();
    _adCtrl.clear();
    _soyadCtrl.clear();
    _vergiDairesiCtrl.clear();
    _adresCtrl.clear();
    _mahalleCtrl.clear();
    _sehirCtrl.clear();
    _binaNoCtrl.clear();
    _kapiNoCtrl.clear();
    _lockAdSoyad = false;
    _lockUnvan = false;
    _queryError = null;
    _showSuggestions = false;
    _suggestions = [];
  }

  CustomerModel _current() => CustomerModel(
        vknTckn: _vknCtrl.text.trim(),
        unvan: _unvanCtrl.text.trim().isEmpty ? null : _unvanCtrl.text.trim(),
        ad: _adCtrl.text.trim().isEmpty ? null : _adCtrl.text.trim(),
        soyad: _soyadCtrl.text.trim().isEmpty ? null : _soyadCtrl.text.trim(),
        vergiDairesi: _vergiDairesiCtrl.text.trim().isEmpty ? null : _vergiDairesiCtrl.text.trim(),
        adres: _adresCtrl.text.trim().isEmpty ? null : _adresCtrl.text.trim(),
        mahalle: _mahalleCtrl.text.trim().isEmpty ? null : _mahalleCtrl.text.trim(),
        sehir: _sehirCtrl.text.trim().isEmpty ? null : _sehirCtrl.text.trim(),
        binaNo: _binaNoCtrl.text.trim().isEmpty ? null : _binaNoCtrl.text.trim(),
        kapiNo: _kapiNoCtrl.text.trim().isEmpty ? null : _kapiNoCtrl.text.trim(),
      );

  void _notify() => widget.onChanged(_current());

  Future<void> _queryGib(String vkn) async {
    if (widget.token == null) {
      setState(() => _queryError = 'GİB oturumu gerekli');
      return;
    }
    setState(() { _querying = true; _queryError = null; });
    try {
      final service = GibService(testMode: widget.testMode);
      final data = await service.getRecipientData(widget.token!, vkn);

      if (data == null || data.isEmpty) {
        setState(() => _queryError = 'GİB\'de kayıt bulunamadı. Bilgileri kontrol edin.');
        return;
      }

      final unvan = _str(data['unvan']) ?? _str(data['ticariUnvan']) ?? '';
      final ad = _str(data['adi']) ?? _str(data['ad']) ?? '';
      final soyad = _str(data['soyadi']) ?? _str(data['soyad']) ?? '';
      final vergiDairesi = _str(data['vergiDairesi']) ?? '';

      final isVkn = vkn.length == 10;
      final isTckn = vkn.length == 11;

      if (isVkn && unvan.isNotEmpty) {
        _unvanCtrl.text = unvan;
        _adCtrl.text = '';
        _soyadCtrl.text = '';
        _lockAdSoyad = true;
        _lockUnvan = false;
      } else if (isTckn && (ad.isNotEmpty || soyad.isNotEmpty)) {
        _adCtrl.text = ad;
        _soyadCtrl.text = soyad;
        _unvanCtrl.text = '';
        _lockUnvan = true;
        _lockAdSoyad = false;
      } else {
        setState(() => _queryError = 'GİB\'den bilgi alınamadı. Bilgileri kontrol edin.');
        return;
      }

      _vergiDairesiCtrl.text = vergiDairesi;

      // Adres bilgilerini yerel kayıttan al
      final local = await _db.getCustomerByVknTckn(vkn);
      if (local != null) {
        _adresCtrl.text = local.adres ?? '';
        _mahalleCtrl.text = local.mahalle ?? '';
        _sehirCtrl.text = local.sehir ?? '';
        _binaNoCtrl.text = local.binaNo ?? '';
        _kapiNoCtrl.text = local.kapiNo ?? '';
      }

      setState(() {});
      // TCKN sorgusu Ünvan alanını kilitlediyse odak Adı alanına geçsin.
      if (_lockUnvan && _unvanFocus.hasFocus) {
        _adFocus.requestFocus();
      }
      _notify();

      if (local == null) await _db.saveCustomer(_current());
    } catch (e) {
      setState(() => _queryError = e.toString().replaceFirst('GibApiException: ', ''));
    } finally {
      if (mounted) setState(() => _querying = false);
    }
  }

  String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Future<void> _onNameChanged(String query) async {
    _notify();
    final combined = [
      _unvanCtrl.text.trim(),
      _adCtrl.text.trim(),
      _soyadCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    final searchQuery = combined.length >= 2 ? combined : query;
    if (searchQuery.length < 2) {
      setState(() => _showSuggestions = false);
      return;
    }
    final results = await _db.searchCustomers(searchQuery);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
      });
    }
  }

  void _selectSuggestion(CustomerModel c) {
    _fill(c);
    final isVkn = c.vknTckn.length == 10;
    final isTckn = c.vknTckn.length == 11;
    setState(() {
      _lockAdSoyad = isVkn && (c.unvan?.isNotEmpty ?? false);
      _lockUnvan = isTckn && (c.ad?.isNotEmpty ?? false);
      _showSuggestions = false;
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // VKN / TCKN
        TextFormField(
          controller: _vknCtrl,
          focusNode: _vknFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) {
            (_lockUnvan ? _adFocus : _unvanFocus).requestFocus();
          },
          keyboardType: TextInputType.number,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'VKN / TC Kimlik No *',
            counterText: '',
            errorText: _queryError,
            suffixIcon: _querying
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _vknCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(_clearAll);
                          _notify();
                        },
                      )
                    : null,
          ),
          onChanged: (v) {
            setState(() => _queryError = null);
            _notify();
          },
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Zorunlu alan';
            if (!AppUtils.isValidVknOrTckn(v.trim())) {
              return 'Geçerli VKN (10 hane) veya TCKN (11 hane) girin';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // Ünvan
        Stack(
          children: [
            TextFormField(
              textCapitalization: TextCapitalization.words,
              controller: _unvanCtrl,
              focusNode: _unvanFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) {
                (_lockAdSoyad ? _vergiDairesiFocus : _adFocus).requestFocus();
              },
              enabled: !_lockUnvan,
              decoration: InputDecoration(
                labelText: 'Ünvan',
                suffixIcon: _lockUnvan
                    ? const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSub)
                    : null,
                fillColor: _lockUnvan ? AppTheme.surface : AppTheme.cardBg,
              ),
              onChanged: _onNameChanged,
            ),
            if (_showSuggestions && !_lockUnvan)
              Positioned(
                top: 58,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (ctx, i) {
                        final s = _suggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text(s.displayName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(s.vknTckn, style: const TextStyle(fontSize: 12)),
                          onTap: () => _selectSuggestion(s),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Ad & Soyad
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textCapitalization: TextCapitalization.words,
                controller: _adCtrl,
                focusNode: _adFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _soyadFocus.requestFocus(),
                enabled: !_lockAdSoyad,
                decoration: InputDecoration(
                  labelText: 'Adı',
                  suffixIcon: _lockAdSoyad
                      ? const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSub)
                      : null,
                  fillColor: _lockAdSoyad ? AppTheme.surface : AppTheme.cardBg,
                ),
                onChanged: (_) => _onNameChanged(_adCtrl.text.trim()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                textCapitalization: TextCapitalization.words,
                controller: _soyadCtrl,
                focusNode: _soyadFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _vergiDairesiFocus.requestFocus(),
                enabled: !_lockAdSoyad,
                decoration: InputDecoration(
                  labelText: 'Soyadı',
                  suffixIcon: _lockAdSoyad
                      ? const Icon(Icons.lock_outline, size: 16, color: AppTheme.textSub)
                      : null,
                  fillColor: _lockAdSoyad ? AppTheme.surface : AppTheme.cardBg,
                ),
                onChanged: (_) => _notify(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Vergi Dairesi
        TextFormField(
          textCapitalization: TextCapitalization.words,
          controller: _vergiDairesiCtrl,
          focusNode: _vergiDairesiFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _adresFocus.requestFocus(),
          decoration: const InputDecoration(labelText: 'Vergi Dairesi'),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 12),

        // Cadde / Sokak
        TextFormField(
          textCapitalization: TextCapitalization.words,
          controller: _adresCtrl,
          focusNode: _adresFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _binaNoFocus.requestFocus(),
          decoration: const InputDecoration(labelText: 'Mahalle / Cadde / Sokak / Site'),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 12),

        // Bina No & Kapı No
        Row(
          children: [
            Expanded(
              child: TextFormField(
                textCapitalization: TextCapitalization.words,
                controller: _binaNoCtrl,
                focusNode: _binaNoFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _kapiNoFocus.requestFocus(),
                decoration: const InputDecoration(labelText: 'Bina No'),
                onChanged: (_) => _notify(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                textCapitalization: TextCapitalization.words,
                controller: _kapiNoCtrl,
                focusNode: _kapiNoFocus,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) => _mahalleFocus.requestFocus(),
                decoration: const InputDecoration(labelText: 'Kapı No'),
                onChanged: (_) => _notify(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mahalle / Semt / İlçe
        TextFormField(
          textCapitalization: TextCapitalization.words,
          controller: _mahalleCtrl,
          focusNode: _mahalleFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _sehirFocus.requestFocus(),
          decoration: const InputDecoration(labelText: 'İlçe'),
          onChanged: (_) => _notify(),
        ),
        const SizedBox(height: 12),

        // Şehir
        TextFormField(
          textCapitalization: TextCapitalization.words,
          controller: _sehirCtrl,
          focusNode: _sehirFocus,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: const InputDecoration(labelText: 'Şehir'),
          onChanged: (_) => _notify(),
        ),
      ],
    );
  }
}
