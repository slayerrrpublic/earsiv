import 'package:intl/intl.dart';

class AppUtils {
  static final _dateFormatter = DateFormat('dd/MM/yyyy');
  static final _timeFormatter = DateFormat('HH:mm:ss');
  static final _displayDateFormatter = DateFormat('d MMM yyyy', 'tr_TR');
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static String todayGib() => _dateFormatter.format(DateTime.now());

  static String gibDateToDisplay(String gibDate) {
    try {
      final parts = gibDate.split('/');
      if (parts.length == 3) {
        final dt = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        return _displayDateFormatter.format(dt);
      }
    } catch (_) {}
    return gibDate;
  }

  static String dateTimeToGib(DateTime dt) => _dateFormatter.format(dt);
  static String timeToGib(DateTime dt) => _timeFormatter.format(dt);

  static String formatCurrency(double amount) =>
      _currencyFormatter.format(amount);

  static String formatNumber(double v) =>
      NumberFormat('#,##0.00', 'tr_TR').format(v);

  static bool isValidVkn(String v) {
    if (v.length != 10) return false;
    if (!RegExp(r'^\d{10}$').hasMatch(v)) return false;
    final digits = v.split('').map(int.parse).toList();
    var v10 = 0;
    for (var i = 0; i < 9; i++) {
      var tmp = (digits[i] + (9 - i)) % 10;
      tmp = (tmp == 9) ? 9 : (tmp * (int.parse('2') << (9 - i - 1)) % 9);
      v10 = (v10 + tmp) % 10;
    }
    final check = (10 - v10) % 10;
    return check == digits[9];
  }

  static bool isValidTckn(String v) {
    if (v.length != 11) return false;
    if (!RegExp(r'^\d{11}$').hasMatch(v)) return false;
    if (v[0] == '0') return false;
    final digits = v.split('').map(int.parse).toList();
    final sum1 =
        (digits[0] + digits[2] + digits[4] + digits[6] + digits[8]) * 7 -
            (digits[1] + digits[3] + digits[5] + digits[7]);
    if (sum1 % 10 != digits[9]) return false;
    final sum2 = digits.sublist(0, 10).reduce((a, b) => a + b);
    return sum2 % 10 == digits[10];
  }

  static bool isValidVknOrTckn(String v) {
    if (v == '11111111111') return true;
    return isValidVkn(v) || isValidTckn(v);
  }

  static String maskPhone(String phone) {
    if (phone.length < 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 3)}';
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'Onaylandı':
        return 'İmzalandı';
      case 'Onaylanmadı':
        return 'Taslak';
      case 'Silinmiş':
        return 'İptal';
      case 'Taslak':
        return 'Yerel';
      default:
        return status;
    }
  }
}
