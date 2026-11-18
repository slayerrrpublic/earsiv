import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';

class GibApiException implements Exception {
  final String message;
  final int? statusCode;
  GibApiException(this.message, {this.statusCode});
  @override
  String toString() => 'GibApiException: $message';
}

class GibService {
  static const String _prodBase = 'https://earsivportal.efatura.gov.tr';
  static const String _testBase = 'https://earsivportaltest.efatura.gov.tr';

  static const String _loginPath = '/earsiv-services/assos-login';
  static const String _dispatchPath = '/earsiv-services/dispatch';

  final bool testMode;
  late final Dio _dio;
  final _uuid = const Uuid();

  String get _base => testMode ? _testBase : _prodBase;

  GibService({this.testMode = false}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
        'Referer': _base,
        'Origin': _base,
      },
    ));
  }


  Future<String> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '$_base$_loginPath',
        data: {
          'assoscmd': testMode ? 'login' : 'anologin',
          'userid': username,
          'sifre': password,
          'sifre2': password,
          'parola': password,
          'rtype': 'json',
        },
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final data = _parseResponse(response);

      // Giriş başarılıysa token döndür.
      final token = data['token']?.toString();

      if (token != null && token.isNotEmpty) {
        return token;
      }

      // Giriş başarısızsa GİB'in gerçek hata mesajını al.
      final messages = data['messages'];

      if (messages is List && messages.isNotEmpty) {
        final message = messages.first;

        if (message is Map && message['text'] != null) {
          throw GibApiException(message['text'].toString());
        }
      }

      throw GibApiException(
        'Giriş başarısız. Sunucudan token alınamadı.',
      );

    } on DioException catch (e) {
      throw GibApiException(_dioError(e));
    }
  }

  Future<void> logout(String token) async {
    try {
      await _dio.post(
        '$_base$_loginPath',
        data: {'assoscmd': 'logout', 'token': token, 'rtype': 'json'},
        options: Options(contentType: 'application/x-www-form-urlencoded; charset=UTF-8'),
      );
    } catch (_) {}
  }

  Future<dynamic> _dispatch(
    String token,
    String cmd,
    String pageName, [
    Map<String, dynamic> payload = const {},
  ]) async {
    try {
      final response = await _dio.post(
        '$_base$_dispatchPath',
        data: {
          'callid': _uuid.v1(),
          'token': token,
          'cmd': cmd,
          'pageName': pageName,
          'jp': jsonEncode(payload.isEmpty ? {} : payload),
          'rtype': 'json',
        },
        options: Options(contentType: 'application/x-www-form-urlencoded; charset=UTF-8'),
      );

      final parsed = _parseResponse(response);
      final result = parsed['data'];

      if (result is List) {
        if (result.isNotEmpty) {
        }
      }

      return result;
    } on DioException catch (e) {
      throw GibApiException(_dioError(e));
    }
  }

  Future<Map<String, dynamic>?> getRecipientData(
      String token, String taxOrTrId) async {
    final data = await _dispatch(
      token,
      'SICIL_VEYA_MERNISTEN_BILGILERI_GETIR',
      'RG_BASITFATURA',
      {'vknTcknn': taxOrTrId},
    );
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    return null;
  }

  Future<String> createDraftInvoice(
      String token, InvoiceModel invoice) async {
    final payload = invoice.toGibJson();
    final data = await _dispatch(
      token,
      'EARSIV_PORTAL_FATURA_OLUSTUR',
      'RG_BASITFATURA',
      payload,
    );
    // Başarısızlık kontrolü: null ya da açıkça hata belirten yanıt
    if (data == null) {
      throw GibApiException('Fatura oluşturulamadı: sunucudan yanıt alınamadı.');
    }
    if (data is String) {
      final lower = data.toLowerCase();
      // Hata içeren anahtar kelimeler
      final hasError = lower.contains('hata') ||
          lower.contains('error') ||
          lower.contains('başarısız') ||
          lower.contains('parametre') ||
          lower.contains('geçersiz');
      // Başarılı yanıt içeriyorsa veya hata yoksa geç
      if (hasError && !lower.contains('başarıyla')) {
        throw GibApiException(data);
      }
    }
    return invoice.uuid;
  }


  Future<List<Map<String, dynamic>>> getInvoicesByDateRange(
      String token, {
        required String startDate,
        required String endDate,
      }) async {
    // Tarih biçimini desteklenen formatlardan çöz.
    DateTime parseDate(String value) {
      final parts = value.trim().split(RegExp(r'[-/.]'));

      if (parts.length != 3) {
        throw GibApiException('Geçersiz tarih biçimi: $value');
      }

      final first = int.parse(parts[0]);
      final second = int.parse(parts[1]);
      final third = int.parse(parts[2]);

      // yyyy-MM-dd veya dd-MM-yyyy biçimini ayırt et.
      final isYearFirst = parts[0].length == 4;

      final date = isYearFirst
          ? DateTime(first, second, third)
          : DateTime(third, second, first);

      if (date.year != (isYearFirst ? first : third) ||
          date.month != second ||
          date.day != (isYearFirst ? third : first)) {
        throw GibApiException('Geçersiz tarih: $value');
      }

      return date;
    }

    // Gelen tarih biçimini koruyarak tekrar metne dönüştür.
    String formatDate(DateTime date, String original) {
      final separator = original.contains('/')
          ? '/'
          : original.contains('.')
          ? '.'
          : '-';

      String two(int n) => n.toString().padLeft(2, '0');

      if (original.trim().split(RegExp(r'[-/.]'))[0].length == 4) {
        return '${date.year}$separator${two(date.month)}$separator${two(date.day)}';
      }

      return '${two(date.day)}$separator${two(date.month)}$separator${date.year}';
    }

    final start = parseDate(startDate);
    final end = parseDate(endDate);

    if (start.isAfter(end)) {
      throw GibApiException('Başlangıç tarihi bitiş tarihinden sonra olamaz.');
    }

    final allInvoices = <Map<String, dynamic>>[];
    var currentStart = start;

    while (!currentStart.isAfter(end)) {
      // Her sorguda en fazla 7 takvim günü.
      final currentEnd = currentStart.add(const Duration(days: 6));
      final chunkEnd = currentEnd.isAfter(end) ? end : currentEnd;

      final data = await _dispatch(
        token,
        'EARSIV_PORTAL_TASLAKLARI_GETIR',
        'RG_TASLAKLAR',
        {
          'baslangic': formatDate(currentStart, startDate),
          'bitis': formatDate(chunkEnd, endDate),
          'hangiTip': '5000/30000',
        },
      );

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            if (item.containsKey('error')) {
              throw GibApiException(item['error'].toString());
            }

            allInvoices.add(item);
          }
        }
      }

      // Sonraki sorgu, önceki sorgunun bittiği günün ertesi günü.
      currentStart = chunkEnd.add(const Duration(days: 1));
    }

    return allInvoices;
  }


  Future<String?> getPhoneNumber(String token) async {
    final data = await _dispatch(
      token,
      'EARSIV_PORTAL_TELEFONNO_SORGULA',
      'RG_BASITTASLAKLAR',
    );
    if (data is Map<String, dynamic>) {
      return data['telefon'] as String?;
    }
    return null;
  }

  Future<String?> startSmsVerification(String token) async {
    final phone = await getPhoneNumber(token);
    if (phone == null) return null;
    final data = await _dispatch(
      token,
      'EARSIV_PORTAL_SMSSIFRE_GONDER',
      'RG_SMSONAY',
      {'CEPTEL': phone, 'KCEPTEL': false, 'TIP': ''},
    );
    if (data is Map<String, dynamic>) {
      return data['oid'] as String?;
    }
    return null;
  }

  Future<bool> completeSmsVerification(
    String token, {
    required String smsCode,
    required String oid,
    required List<String> uuids,
  }) async {
    final setToSign = uuids
        .map((u) => {'belgeTuru': 'FATURA', 'ettn': u})
        .toList();
    final data = await _dispatch(
      token,
      '0lhozfib5410mp',
      'RG_SMSONAY',
      {'DATA': setToSign, 'SIFRE': smsCode, 'OID': oid, 'OPR': 1},
    );
    if (data is Map<String, dynamic>) {
      return data['sonuc'] == '1';
    }
    return false;
  }

  Future<String> getInvoiceHtml(
      String token,
      String uuid, {
        bool signed = true,
      }) async {
    final data = await _dispatch(
      token,
      'EARSIV_PORTAL_FATURA_GOSTER',
      'RG_TASLAKLAR',
      {
        'ettn': uuid,
        'onayDurumu': signed ? 'Onaylandi' : 'Onaylanmadi',
      },
    );
    return data?.toString() ?? '';
  }


  Future<bool> cancelDraftInvoice(
    String token,
    String uuid,
    String reason,
  ) async {
    final data = await _dispatch(
      token,
      'EARSIV_PORTAL_FATURA_SIL',
      'RG_TASLAKLAR',
      {
        'silinecekler': [
          {'belgeTuru': 'FATURA', 'ettn': uuid}
        ],
        'aciklama': reason,
      },
    );
    return data != null;
  }

  Map<String, dynamic> _parseResponse(Response response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is String) {
      try {
        return jsonDecode(response.data as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    throw GibApiException('Beklenmeyen sunucu yanıtı.');
  }

  String _dioError(DioException e) {
    if (e.response != null) {
      return 'Sunucu hatası: ${e.response?.statusCode}';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Bağlantı zaman aşımı. İnternet bağlantınızı kontrol edin.';
    }
    return 'Ağ hatası: ${e.message}';
  }
}

