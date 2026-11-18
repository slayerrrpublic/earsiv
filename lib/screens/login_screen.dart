import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'main_screen.dart';
import '../services/database_service.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;

  const LoginScreen({super.key, required this.authService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _testMode = false;
  bool _suggestingUser = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedUsername();
  }

  Future<void> _loadSavedUsername() async {
    final creds = await widget.authService.getSavedCredentials();

    if (!mounted) return;

    if (creds['username'] != null) {
      setState(() => _userCtrl.text = creds['username']!);
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // GİB test portalından test kullanıcısı öner
  Future<void> _suggestTestUser() async {
    setState(() {
      _suggestingUser = true;
      _error = null;
    });

    try {
      final response = await Dio().post(
        'https://earsivportaltest.efatura.gov.tr/earsiv-services/esign',
        data: {
          'assoscmd': 'kullaniciOner',
          'rtype': 'json',
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded;charset=UTF-8',
        ),
      );

      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      final userId = data['userid']?.toString();

      if (userId == null || userId.isEmpty) {
        throw Exception('GİB test kullanıcısı döndürmedi.');
      }

      if (!mounted) return;

      setState(() {
        _userCtrl.text = userId;
        _passCtrl.text = '1';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test kullanıcısı alındı: $userId'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Test kullanıcısı alınamadı: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _suggestingUser = false);
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.authService.login(
        _userCtrl.text.trim(),
        _passCtrl.text,
        testMode: _testMode,
      );
      await DatabaseService.instance.setUser(
        username: _userCtrl.text.trim(),
        testMode: _testMode,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MainScreen(authService: widget.authService),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('GibApiException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),

            // Logo alanı
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 40,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'eArşiv Fatura',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'GİB eArşiv Portalı',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 40),

            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      const SizedBox(height: 8),

                      const Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'GİB kullanıcı bilgilerinizi girin',
                        style: TextStyle(
                          color: AppTheme.textSub,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 28),

                      TextFormField(
                        controller: _userCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Kullanıcı Adı',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Kullanıcı adı gerekli'
                            : null,
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passCtrl,
                        keyboardType: TextInputType.number,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscure = !_obscure);
                            },
                          ),
                        ),
                        validator: (v) =>
                        (v == null || v.isEmpty)
                            ? 'Şifre gerekli'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      // Test modu ve kullanıcı öner butonu
                      Row(
                        children: [
                          Checkbox(
                            value: _testMode,
                            activeColor: AppTheme.warning,
                            onChanged: (v) {
                              setState(() {
                                _testMode = v ?? false;
                                _error = null;
                              });
                            },
                          ),

                          const Text(
                            'Test Modu',
                            style: TextStyle(fontSize: 14),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(3),
                            child: GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Test Modu'),
                                    content: const Text(
                                      'Test modunda gerçek fatura kesilmez.\n'
                                          'earsivportaltest.efatura.gov.tr kullanılır.\n\n'
                                          'Kullanıcı öner butonu ile test modu için kullanıcı adı ve şifre alabilirsiniz.\n\n'
                                          'Test moduna gerçek kullanıcı bilgisiyle, gerçek moda test kullancı bilgisiyle girilemez.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Tamam'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppTheme.textSub,
                              ),
                            ),
                          ),

                          if (_testMode) ...[
                            const Spacer(),

                            SizedBox(
                              width: 155,
                              child: OutlinedButton.icon(
                                onPressed: _suggestingUser ? null : _suggestTestUser,
                                icon: _suggestingUser
                                    ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                    : const Icon(Icons.person_add_alt_1, size: 20),
                                label: const Text(
                                  'Kullanıcı Öner',
                                  maxLines: 1,
                                  softWrap: false,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.warning,
                                  minimumSize: const Size(155, 42),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppTheme.error,
                                size: 18,
                              ),

                              const SizedBox(width: 8),

                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Text('Giriş Yap'),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}