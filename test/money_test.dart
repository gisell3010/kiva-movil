import 'package:flutter_test/flutter_test.dart';
import 'package:kiva_mobile_final/models/money.dart';

void main() {
  test('Importes conservan los centavos y separadores colombianos', () {
    expect(formatMoney('1234567.09'), '1.234.567,09 COP');
    expect(formatMoney('0.01'), '0,01 COP');
    expect(formatMoney('-12.5'), '-12,50 COP');
    expect(formatMoney('9999999999999999.99'), '9.999.999.999.999.999,99 COP');
    expect(formatMoney('NaN'), '—');
  });
}
