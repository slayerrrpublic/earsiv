import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/app_theme.dart';
import '../widgets/customer_picker_widget.dart';
import 'new_invoice_screen.dart';

class CustomersScreen extends StatefulWidget {
  final AuthService authService;
  const CustomersScreen({super.key, required this.authService});

  @override
  State<CustomersScreen> createState() => CustomersScreenState();
}

class CustomersScreenState extends State<CustomersScreen> {
  final _db = DatabaseService.instance;
  final _searchCtrl = TextEditingController();
  List<CustomerModel> _customers = [];
  List<CustomerModel> _filtered = [];
  bool _loading = false;

  void reload() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _customers = await _db.getAllCustomers();
    _filtered = List.from(_customers);
    if (mounted) setState(() => _loading = false);
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_customers)
          : _customers
              .where((c) =>
                  c.displayName.toLowerCase().contains(q) ||
                  c.vknTckn.contains(q))
              .toList();
    });
  }

  Future<void> _showAddEdit([CustomerModel? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerEditSheet(
        initial: existing,
        token: widget.authService.token,
        testMode: widget.authService.testMode,
        onSave: (c) async {
          await _db.saveCustomer(c);
          Navigator.pop(ctx);
          _load();
        },
      ),
    );
  }

  Future<void> _delete(CustomerModel c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi Sil'),
        content: Text('${c.displayName} silinsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteCustomer(c.vknTckn);
      _load();
    }
  }

  void _createInvoiceFor(CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Yeni Fatura — ${customer.displayName}')),
          body: NewInvoiceScreen(
            authService: widget.authService,
            initialCustomer: customer,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppTheme.cardBg,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'İsim veya VKN/TCKN ara...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch();
                      },
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final c = _filtered[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.1),
                              child: Text(
                                c.displayName.isNotEmpty
                                    ? c.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text(c.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [
                                c.vknTckn,
                                if (c.vergiDairesi?.isNotEmpty ?? false)
                                  c.vergiDairesi,
                              ].join(' · '),
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'invoice') _createInvoiceFor(c);
                                if (v == 'edit') _showAddEdit(c);
                                if (v == 'delete') _delete(c);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'invoice',
                                  child: Row(children: [
                                    Icon(Icons.receipt_long,
                                        size: 18, color: AppTheme.primary),
                                    SizedBox(width: 8),
                                    Text('Fatura Kes',
                                        style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Düzenle'),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    Icon(Icons.delete,
                                        size: 18, color: AppTheme.error),
                                    SizedBox(width: 8),
                                    Text('Sil',
                                        style: TextStyle(
                                            color: AppTheme.error)),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 64, color: AppTheme.textSub.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('Kayıtlı müşteri yok',
              style: TextStyle(color: AppTheme.textSub, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'Fatura keserken girdiğiniz müşteriler\notomatik olarak buraya kaydedilir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSub, fontSize: 13),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 180,
            child: OutlinedButton.icon(
              onPressed: () => _showAddEdit(),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Müşteri Ekle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerEditSheet extends StatefulWidget {
  final CustomerModel? initial;
  final String? token;
  final bool testMode;
  final Future<void> Function(CustomerModel) onSave;

  const _CustomerEditSheet({
    this.initial,
    this.token,
    this.testMode = false,
    required this.onSave,
  });

  @override
  State<_CustomerEditSheet> createState() => _CustomerEditSheetState();
}

class _CustomerEditSheetState extends State<_CustomerEditSheet> {
  final _formKey = GlobalKey<FormState>();
  CustomerModel? _customer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.initial;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_customer == null || _customer!.vknTckn.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(_customer!);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    widget.initial == null
                        ? 'Yeni Müşteri'
                        : 'Müşteriyi Düzenle',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    CustomerPickerWidget(
                      initial: widget.initial,
                      token: widget.token,
                      testMode: widget.testMode,
                      onChanged: (c) => setState(() => _customer = c),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Kaydet'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
