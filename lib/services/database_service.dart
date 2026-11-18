import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';


class DatabaseService {
  static DatabaseService? _instance;
  static Database? _db;
  static String? _databaseName;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  // Giriş yapan kullanıcıya özel veritabanını seçer.
  Future<void> setUser({
    required String username,
    required bool testMode,
  }) async {
    final user = username.trim();

    if (user.isEmpty) {
      throw ArgumentError('Kullanıcı adı boş olamaz.');
    }

    // Önce açık olan veritabanını kapat.
    if (_db != null) {
      await _db!.close();
      _db = null;
    }

    final safeUsername = user.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final mode = testMode ? 'test' : 'real';

    _databaseName = 'efatura_${mode}_$safeUsername.db';

    // Eski ortak veritabanını sil.
    final databasesPath = await getDatabasesPath();
    final oldPath = join(databasesPath, 'efatura7.db');
    await deleteDatabase(oldPath);
  }

  Future<Database> get db async {
    if (_databaseName == null) {
      throw StateError(
        'Veritabanı için önce kullanıcı girişi yapılmalıdır.',
      );
    }

    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(
      await getDatabasesPath(),
      _databaseName!,
    );

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final col in ['mahalle', 'sehir', 'binaNo', 'kapiNo']) {
        try { await db.execute('ALTER TABLE customers ADD COLUMN $col TEXT'); } catch (_) {}
      }
      for (final col in ['aliciMahalle', 'aliciSehir', 'aliciBinaNo', 'aliciKapiNo']) {
        try { await db.execute('ALTER TABLE invoices ADD COLUMN $col TEXT'); } catch (_) {}
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vknTckn TEXT NOT NULL UNIQUE,
        unvan TEXT,
        ad TEXT,
        soyad TEXT,
        vergiDairesi TEXT,
        adres TEXT,
        mahalle TEXT,
        sehir TEXT,
        binaNo TEXT,
        kapiNo TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        faturaNo TEXT,
        tarih TEXT NOT NULL,
        saat TEXT NOT NULL,
        aliciVknTckn TEXT,
        aliciUnvan TEXT,
        aliciAd TEXT,
        aliciSoyad TEXT,
        aliciVergiDairesi TEXT,
        aliciAdres TEXT,
        aliciMahalle TEXT,
        aliciSehir TEXT,
        aliciBinaNo TEXT,
        aliciKapiNo TEXT,
        toplamTutar REAL NOT NULL,
        kdvTutar REAL NOT NULL,
        genelToplam REAL NOT NULL,
        kalemlerJson TEXT NOT NULL,
        onayDurumu TEXT DEFAULT 'Taslak',
        notlar TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE incomeInvoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tarih TEXT NOT NULL,
        satici TEXT NOT NULL,
        gelenTutar REAL NOT NULL,
        gelenKdv REAL NOT NULL,
        gelenToplam REAL NOT NULL
      )
    ''');

  }

  // ─── CUSTOMERS ───────────────────────────────────────────────────────────────

  Future<int> saveCustomer(CustomerModel c) async {
    final database = await db;
    final now = DateTime.now().toIso8601String();
    return database.insert(
      'customers',
      {
        'vknTckn': c.vknTckn,
        'unvan': c.unvan,
        'ad': c.ad,
        'soyad': c.soyad,
        'vergiDairesi': c.vergiDairesi,
        'adres': c.adres,
        'mahalle': c.mahalle,
        'sehir': c.sehir,
        'binaNo': c.binaNo,
        'kapiNo': c.kapiNo,
        'createdAt': now,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CustomerModel>> getAllCustomers() async {
    final database = await db;
    final rows = await database.query('customers', orderBy: 'updatedAt DESC');
    return rows.map(CustomerModel.fromDb).toList();
  }

  Future<List<CustomerModel>> searchCustomers(String query) async {
    final database = await db;
    final q = '%$query%';
    final rows = await database.query(
      'customers',
      where:
          'unvan LIKE ? OR ad LIKE ? OR soyad LIKE ? OR vknTckn LIKE ?',
      whereArgs: [q, q, q, q],
      orderBy: 'updatedAt DESC',
      limit: 10,
    );
    return rows.map(CustomerModel.fromDb).toList();
  }

  Future<CustomerModel?> getCustomerByVknTckn(String vknTckn) async {
    final database = await db;
    final rows = await database.query(
      'customers',
      where: 'vknTckn = ?',
      whereArgs: [vknTckn],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CustomerModel.fromDb(rows.first);
  }

  Future<int> deleteCustomer(String vknTckn) async {
    final database = await db;
    return database
        .delete('customers', where: 'vknTckn = ?', whereArgs: [vknTckn]);
  }

  // ─── INVOICES ─────────────────────────────────────────────────────────────────

  Future<int> saveInvoice(InvoiceModel inv) async {
    final database = await db;
    final now = DateTime.now().toIso8601String();
    return database.insert(
      'invoices',
      {
        'uuid': inv.uuid,
        'faturaNo': inv.faturaNo,
        'tarih': inv.tarih,
        'saat': inv.saat,
        'aliciVknTckn': inv.customer.vknTckn,
        'aliciUnvan': inv.customer.unvan,
        'aliciAd': inv.customer.ad,
        'aliciSoyad': inv.customer.soyad,
        'aliciVergiDairesi': inv.customer.vergiDairesi,
        'aliciAdres': inv.customer.adres,
        'aliciMahalle': inv.customer.mahalle,
        'aliciSehir': inv.customer.sehir,
        'aliciBinaNo': inv.customer.binaNo,
        'aliciKapiNo': inv.customer.kapiNo,
        'toplamTutar': inv.toplamTutar,
        'kdvTutar': inv.kdvTutar,
        'genelToplam': inv.genelToplam,
        'kalemlerJson': inv.kalemlerJson,
        'onayDurumu': inv.onayDurumu,
        'notlar': inv.notlar,
        'createdAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<InvoiceModel>> getAllInvoices({
    String? startDate,
    String? endDate,
  }) async {
    final database = await db;
    String? where;
    List<dynamic>? whereArgs;
    if (startDate != null && endDate != null) {
      where = 'tarih >= ? AND tarih <= ?';
      whereArgs = [startDate, endDate];
    }
    final rows = await database.query(
      'invoices',
      where: where,
      whereArgs: whereArgs,
    );
    final invoices = rows.map(InvoiceModel.fromDb).toList();
    invoices.sort((a, b) {
      try {
        DateTime parseGib(String tarih, String saat) {
          final p = tarih.split('/');
          final t = saat.split(':');
          return DateTime(
            int.parse(p[2]), int.parse(p[1]), int.parse(p[0]),
            t.length > 2 ? int.parse(t[0]) : 0,
            t.length > 2 ? int.parse(t[1]) : 0,
            t.length > 2 ? int.parse(t[2]) : 0,
          );
        }
        // GİB'den gelen tarih tire ile de gelebilir
        String normTarih(String d) => d.replaceAll('-', '/');
        final dtA = parseGib(normTarih(a.tarih), a.saat);
        final dtB = parseGib(normTarih(b.tarih), b.saat);
        return dtB.compareTo(dtA); // en yeni en üstte
      } catch (_) {
        return 0;
      }
    });
    return invoices;
  }

  Future<InvoiceModel?> getInvoiceByUuid(String uuid) async {
    final database = await db;
    final rows = await database
        .query('invoices', where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    if (rows.isEmpty) return null;
    return InvoiceModel.fromDb(rows.first);
  }

  Future<int> updateInvoiceStatus(String uuid, String status,
      {String? faturaNo}) async {
    final database = await db;
    final data = <String, dynamic>{'onayDurumu': status};
    if (faturaNo != null) data['faturaNo'] = faturaNo;
    return database
        .update('invoices', data, where: 'uuid = ?', whereArgs: [uuid]);
  }

}
