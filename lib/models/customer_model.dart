class CustomerModel {
  final String vknTckn;
  final String? unvan;
  final String? ad;
  final String? soyad;
  final String? vergiDairesi;
  final String? adres;        // Cadde/sokak
  final String? mahalle;      // Mahalle/semt/ilçe
  final String? sehir;        // Şehir
  final String? binaNo;       // Bina no
  final String? kapiNo;       // Kapı no

  const CustomerModel({
    required this.vknTckn,
    this.unvan,
    this.ad,
    this.soyad,
    this.vergiDairesi,
    this.adres,
    this.mahalle,
    this.sehir,
    this.binaNo,
    this.kapiNo,
  });

  String get displayName {
    if (unvan != null && unvan!.isNotEmpty) return unvan!;
    final full = [ad, soyad].where((e) => e != null && e.isNotEmpty).join(' ');
    return full.isNotEmpty ? full : vknTckn;
  }

  bool get isCompany => vknTckn.length == 10;

  CustomerModel copyWith({
    String? vknTckn,
    String? unvan,
    String? ad,
    String? soyad,
    String? vergiDairesi,
    String? adres,
    String? mahalle,
    String? sehir,
    String? binaNo,
    String? kapiNo,
  }) {
    return CustomerModel(
      vknTckn: vknTckn ?? this.vknTckn,
      unvan: unvan ?? this.unvan,
      ad: ad ?? this.ad,
      soyad: soyad ?? this.soyad,
      vergiDairesi: vergiDairesi ?? this.vergiDairesi,
      adres: adres ?? this.adres,
      mahalle: mahalle ?? this.mahalle,
      sehir: sehir ?? this.sehir,
      binaNo: binaNo ?? this.binaNo,
      kapiNo: kapiNo ?? this.kapiNo,
    );
  }

  factory CustomerModel.fromDb(Map<String, dynamic> row) {
    return CustomerModel(
      vknTckn: row['vknTckn'] as String,
      unvan: row['unvan'] as String?,
      ad: row['ad'] as String?,
      soyad: row['soyad'] as String?,
      vergiDairesi: row['vergiDairesi'] as String?,
      adres: row['adres'] as String?,
      mahalle: row['mahalle'] as String?,
      sehir: row['sehir'] as String?,
      binaNo: row['binaNo'] as String?,
      kapiNo: row['kapiNo'] as String?,
    );
  }

  factory CustomerModel.fromGibResponse(Map<String, dynamic> data) {
    return CustomerModel(
      vknTckn: (data['vknTcknn'] ?? data['vkn'] ?? '') as String,
      unvan: _s(data['unvan']) ?? _s(data['ticariUnvan']),
      ad: _s(data['adi']) ?? _s(data['ad']),
      soyad: _s(data['soyadi']) ?? _s(data['soyad']),
      vergiDairesi: _s(data['vergiDairesi']),
      adres: _s(data['caddeAdi']) ?? _s(data['adres']),
      mahalle: _s(data['mahalleSemtIlce']),
      sehir: _s(data['sehir']),
      binaNo: _s(data['binaNo']),
      kapiNo: _s(data['kapiNo']),
    );
  }

  static String? _s(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic> toJson() => {
        'vknTckn': vknTckn,
        'unvan': unvan ?? '',
        'ad': ad ?? '',
        'soyad': soyad ?? '',
        'vergiDairesi': vergiDairesi ?? '',
        'adres': adres ?? '',
        'mahalle': mahalle ?? '',
        'sehir': sehir ?? '',
        'binaNo': binaNo ?? '',
        'kapiNo': kapiNo ?? '',
      };
}
