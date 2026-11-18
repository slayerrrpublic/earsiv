import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'gib_service.dart';

class AuthService {
  static const _keyUsername = 'gib_username';
  static const _keyPassword = 'gib_password';
  static const _keyToken = 'gib_token';
  static const _keyTestMode = 'gib_test_mode';

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _token;
  String? _username;
  bool _testMode = false;

  String? get token => _token;
  String? get username => _username;
  bool get testMode => _testMode;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    _token = await _storage.read(key: _keyToken);
    _username = await _storage.read(key: _keyUsername);
    final tm = await _storage.read(key: _keyTestMode);
    _testMode = tm == 'true';
  }

  Future<String> login(
    String username,
    String password, {
    bool testMode = false,
  }) async {
    _testMode = testMode;
    final service = GibService(testMode: testMode);
    final token = await service.login(username, password);

    _token = token;
    _username = username;

    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyTestMode, value: testMode.toString());

    return token;
  }

  Future<String> reLogin() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    if (username == null || password == null) {
      throw GibApiException('Kayıtlı oturum bilgisi bulunamadı.');
    }
    return login(username, password, testMode: _testMode);
  }

  Future<void> logout() async {
    if (_token != null) {
      try {
        final service = GibService(testMode: _testMode);
        await service.logout(_token!);
      } catch (_) {}
    }
    _token = null;
    _username = null;
    await _storage.delete(key: _keyToken);
  }

  Future<void> clearAll() async {
    _token = null;
    _username = null;
    await _storage.deleteAll();
  }

  Future<Map<String, String?>> getSavedCredentials() async {
    return {
      'username': await _storage.read(key: _keyUsername),
      'password': await _storage.read(key: _keyPassword),
    };
  }
}
