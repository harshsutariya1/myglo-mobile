import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/utils/phone_numbers.dart';

void main() {
  group('PhoneNumbers.toE164', () {
    test('Australian mobiles, however they are typed', () {
      for (final input in ['0412 345 678', '0412345678', '(0412) 345-678', '+61 412 345 678', '61412345678', ' 0412.345.678 ']) {
        expect(PhoneNumbers.toE164(input), '+61412345678', reason: input);
      }
    });

    test('other countries need their country code', () {
      expect(PhoneNumbers.toE164('+64 21 123 4567'), '+64211234567');
      expect(PhoneNumbers.toE164('+91 98765 43210'), '+919876543210');
      expect(PhoneNumbers.toE164('021 123 4567'), isNull);
    });

    test('refuses what cannot be texted', () {
      for (final input in [null, '', '   ', '0412', '04123456789', '07 5555 1234', '+0412345678', '+61', 'abc', '+61412345678901234']) {
        expect(PhoneNumbers.toE164(input), isNull, reason: '$input');
      }
    });
  });

  test('same compares numbers, not how they were typed', () {
    expect(PhoneNumbers.same('0412 345 678', '+61412345678'), isTrue);
    expect(PhoneNumbers.same('0412 345 678', '0412 345 679'), isFalse);
    expect(PhoneNumbers.same('', ''), isFalse);
    expect(PhoneNumbers.same(null, '+61412345678'), isFalse);
  });

  test('validateRequired: a phone number is mandatory and must be plausible', () {
    expect(PhoneNumbers.validateRequired(null), 'Phone number is required');
    expect(PhoneNumbers.validateRequired('   '), 'Phone number is required');
    expect(PhoneNumbers.validateRequired('12345'), contains('valid phone number'));
    expect(PhoneNumbers.validateRequired('call me'), contains('valid phone number'));
    expect(PhoneNumbers.validateRequired('0412 345 678'), isNull);
    expect(PhoneNumbers.validateRequired('+61 412 345 678'), isNull);
    expect(PhoneNumbers.validateRequired('(07) 5555 1234'), isNull);
  });

  test('display writes Australian mobiles the local way and leaves the rest', () {
    expect(PhoneNumbers.display('+61412345678'), '0412 345 678');
    expect(PhoneNumbers.display('0412345678'), '0412 345 678');
    expect(PhoneNumbers.display('+64211234567'), '+64211234567');
    expect(PhoneNumbers.display('07 5555 1234'), '07 5555 1234');
    expect(PhoneNumbers.display(null), '');
  });
}
