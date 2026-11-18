import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'invoice_list_screen.dart';
import 'new_invoice_screen.dart';
import 'customers_screen.dart';
import 'login_screen.dart';
import 'kullanim_kilavuzu_screen.dart';

class MainScreen extends StatefulWidget {
  final AuthService authService;
  const MainScreen({super.key, required this.authService});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  Key _newInvoiceKey = UniqueKey(); // her sıfırlamada yeni key → widget yeniden oluşur

  // Her sekme için key — değişince widget yeniden oluşturulur (yenilenir)
  final _invoiceListKey = GlobalKey<InvoiceListScreenState>();
  final _customersKey = GlobalKey<CustomersScreenState>();

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await widget.authService.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginScreen(authService: widget.authService),
        ),
      );
    }
  }

  void _onTabChanged(int index) {
    if (index == 0) {
      _invoiceListKey.currentState?.reload();
    } else if (index == 2) {
      _customersKey.currentState?.reload();
    }
    // Yeni Fatura sekmesinden ayrılınca formu sıfırla
    if (_selectedIndex == 1 && index != 1) {
      setState(() {
        _newInvoiceKey = UniqueKey();
        _selectedIndex = index;
      });
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Faturalar', 'Yeni Fatura', 'Müşteriler', 'Vergi Muhasebesi'];
    return Scaffold(

      appBar: AppBar(
        centerTitle: true,
        title: Text(titles[_selectedIndex]),

        leading: IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Kullanım Kılavuzu',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const KullanimKilavuzuScreen(),
              ),
            );
          },
        ),

        actions: [
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Çıkış Yap',
              onPressed: _logout,
            ),
        ],
      ),

      body: IndexedStack(
        index: _selectedIndex,
        children: [
          InvoiceListScreen(
              key: _invoiceListKey, authService: widget.authService),
          NewInvoiceScreen(key: _newInvoiceKey, authService: widget.authService),
          CustomersScreen(
              key: _customersKey, authService: widget.authService),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabChanged,
        backgroundColor: AppTheme.cardBg,
        indicatorColor: AppTheme.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt, color: AppTheme.primary),
            label: 'Faturalar',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: AppTheme.primary),
            label: 'Yeni Fatura',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: AppTheme.primary),
            label: 'Müşteriler',
          ),
        ],
      ),
    );
  }
}
