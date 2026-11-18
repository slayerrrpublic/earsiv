import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/database_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  final authService = AuthService();
  await authService.init();

  // Kayıtlı oturum varsa kullanıcının veritabanını seç.
  if (authService.isLoggedIn && authService.username != null) {
    await DatabaseService.instance.setUser(
      username: authService.username!,
      testMode: authService.testMode,
    );
  }

  runApp(EFaturaApp(authService: authService));
}


class EFaturaApp extends StatelessWidget {
  final AuthService authService;
  const EFaturaApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eArşiv Fatura',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('tr', 'TR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      home: authService.isLoggedIn
          ? MainScreen(authService: authService)
          : LoginScreen(authService: authService),
    );
  }
}
