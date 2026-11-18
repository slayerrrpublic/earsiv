import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'customer_model.dart';

class InvoiceItem {
  final String malHizmet;
  final double miktar;
  final String birim;
  final double birimFiyat;
  final double fiyat;
  final double kdvOrani;
  final double kdvTutar;

  const InvoiceItem({
    required this.malHizmet,
    required this.miktar,
    this.birim = 'ADET',
    required this.birimFiyat,
    required this.fiyat,
    this.kdvOrani = 20,
    required this.kdvTutar,
  });

  factory InvoiceItem.create({
    required String malHizmet,
    required double miktar,
    String birim = 'ADET',
    required double birimFiyat,
    double kdvOrani = 20,
  }) {
    final fiyat = miktar * birimFiyat;
    final kdvTutar = fiyat * (kdvOrani / 100);
    return InvoiceItem(
      malHizmet: malHizmet,
      miktar: miktar,
      birim: birim,
      birimFiyat: birimFiyat,
      fiyat: fiyat,
      kdvOrani: kdvOrani,
      kdvTutar: kdvTutar,
    );
  }

  Map<String, dynamic> toGibJson() => {
        'malHizmet': malHizmet,
        'miktar': miktar,
        'birim': birim,
        'birimFiyat': _fmt(birimFiyat),
        'fiyat': _fmt(fiyat),
        'iskontoOrani': 0,
        'iskontoTutari': '0',
        'iskontoNedeni': '',
        'malHizmetTutari': _fmt(fiyat),
        'kdvOrani': kdvOrani.toInt(),
        'vergiOrani': 0,
        'kdvTutari': _fmt(kdvTutar),       // kdvTutari (i ile)
        'vergininKdvTutari': '0',
        'ozelMatrahTutari': '0',
      };

  Map<String, dynamic> toJson() => {
        'malHizmet': malHizmet,
        'miktar': miktar,
        'birim': birim,
        'birimFiyat': birimFiyat,
        'fiyat': fiyat,
        'kdvOrani': kdvOrani,
        'kdvTutar': kdvTutar,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        malHizmet: j['malHizmet'] as String,
        miktar: (j['miktar'] as num).toDouble(),
        birim: j['birim'] as String? ?? 'ADET',
        birimFiyat: (j['birimFiyat'] as num).toDouble(),
        fiyat: (j['fiyat'] as num).toDouble(),
        kdvOrani: (j['kdvOrani'] as num?)?.toDouble() ?? 20,
        kdvTutar: (j['kdvTutar'] as num).toDouble(),
      );

  String _fmt(double v) => v.toStringAsFixed(2);
}

class InvoiceModel {
  final String uuid;
  final String? faturaNo;
  final String tarih;   // dd/MM/yyyy
  final String saat;    // HH:mm:ss
  final CustomerModel customer;
  final List<InvoiceItem> items;
  final String? notlar;
  final String onayDurumu;

  InvoiceModel({
    String? uuid,
    this.faturaNo,
    required this.tarih,
    required this.saat,
    required this.customer,
    required this.items,
    this.notlar,
    this.onayDurumu = 'Taslak',
  }) : uuid = uuid ?? const Uuid().v4();

  double get toplamTutar => items.fold(0, (s, i) => s + i.fiyat);
  double get kdvTutar    => items.fold(0, (s, i) => s + i.kdvTutar);
  double get genelToplam => toplamTutar + kdvTutar;

  String get kalemlerJson =>
      jsonEncode(items.map((i) => i.toJson()).toList());

  Map<String, dynamic> toGibJson() {
    return {
      // ── Fatura kimliği ─────────────────────────────────────────
      'faturaUuid': '',
      'belgeNumarasi': '',             // GİB otomatik atar

      // ── Tarih / saat ───────────────────────────────────────────
      'faturaTarihi': tarih,           // dd/MM/yyyy
      'saat': saat,                    // HH:mm:ss

      // ── Para birimi ────────────────────────────────────────────
      'paraBirimi': 'TRY',
      'dovzTLkur': '0',

      // ── Fatura tipi ────────────────────────────────────────────
      'faturaTipi': 'SATIS',
      'hangiTip': '5000/30000',

      // ── Alıcı bilgileri ────────────────────────────────────────
      'vknTckn': customer.vknTckn,
      'aliciUnvan': customer.unvan ?? '',
      'aliciAdi': customer.ad ?? '',       // aliciAdi  (Adi)
      'aliciSoyadi': customer.soyad ?? '', // aliciSoyadi (Soyadi)
      'vergiDairesi': customer.vergiDairesi ?? '',

      // ── Adres alanları (çoğu zorunlu değil) ───────────────────
      'bulvarcaddesokak': customer.adres ?? '',
      'mahalleSemtIlce': customer.mahalle ?? '',
      'sehir': customer.sehir ?? ' ',
      'ulke': '/ Türkiye',
      'binaAdi': '',
      'binaNo': customer.binaNo ?? '',
      'kapiNo': customer.kapiNo ?? '',
      'kasabaKoy': '',
      'postaKodu': '',
      'tel': '',
      'fax': '',
      'eposta': '',
      'websitesi': '',

      // ── Sevk/irsaliye (zorunlu değil) ─────────────────────────
      'irsaliyeNumarasi': '',
      'irsaliyeTarihi': '',
      'siparisNumarasi': '',
      'siparisTarihi': '',
      'fisNo': '',
      'fisTarihi': '',
      'fisSaati': ' ',
      'fisTipi': ' ',
      'zRaporNo': '',
      'okcSeriNo': '',

      // ── Kalemler ───────────────────────────────────────────────
      'malHizmetTable': items.map((i) => i.toGibJson()).toList(),

      // ── İskonto/özel matrah (kullanılmıyor) ───────────────────
      'tip': 'İskonto',
      'iadeTable': [],
      'ozelMatrahTutari': '0',
      'ozelMatrahOrani': 0,
      'ozelMatrahVergiTutari': '0',
      'vergiCesidi': ' ',

      // ── Toplamlar ──────────────────────────────────────────────
      'matrah': toplamTutar,                        // sayı (string değil)
      'malhizmetToplamTutari': toplamTutar,         // sayı
      'toplamIskonto': '0',
      'hesaplanankdv': kdvTutar,                    // hesaplanankdv (küçük k)
      'vergilerToplami': kdvTutar,                  // sayı
      'vergilerDahilToplamTutar': genelToplam,      // vergilerDahilToplamTutar
      'odenecekTutar': genelToplam,                 // sayı

      // ── Not ────────────────────────────────────────────────────
      'not': notlar ?? '',
    };
  }

  factory InvoiceModel.fromDb(Map<String, dynamic> row) {
    final itemsRaw =
        jsonDecode(row['kalemlerJson'] as String) as List<dynamic>;
    return InvoiceModel(
      uuid: row['uuid'] as String,
      faturaNo: row['faturaNo'] as String?,
      tarih: row['tarih'] as String,
      saat: row['saat'] as String,
      customer: CustomerModel(
        vknTckn: row['aliciVknTckn'] as String? ?? '',
        unvan: row['aliciUnvan'] as String?,
        ad: row['aliciAd'] as String?,
        soyad: row['aliciSoyad'] as String?,
        vergiDairesi: row['aliciVergiDairesi'] as String?,
        adres: row['aliciAdres'] as String?,
        mahalle: row['aliciMahalle'] as String?,
        sehir: row['aliciSehir'] as String?,
        binaNo: row['aliciBinaNo'] as String?,
        kapiNo: row['aliciKapiNo'] as String?,
      ),
      items: itemsRaw
          .map((e) => InvoiceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      notlar: row['notlar'] as String?,
      onayDurumu: row['onayDurumu'] as String? ?? 'Taslak',
    );
  }

  InvoiceModel copyWith({String? onayDurumu, String? faturaNo}) {
    return InvoiceModel(
      uuid: uuid,
      faturaNo: faturaNo ?? this.faturaNo,
      tarih: tarih,
      saat: saat,
      customer: customer,
      items: items,
      notlar: notlar,
      onayDurumu: onayDurumu ?? this.onayDurumu,
    );
  }
}
