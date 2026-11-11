/// Phone numbers as the SMS sender needs them (E.164, e.g. `+61412345678`)
/// and as people read them.
class PhoneNumbers {
  PhoneNumbers._();

  static final RegExp _separators = RegExp(r'[\s\-().]');
  static final RegExp _international = RegExp(r'^\+[1-9]\d{7,14}$');
  static final RegExp _australianMobileLocal = RegExp(r'^04\d{8}$');
  static final RegExp _australianMobileNoPlus = RegExp(r'^614\d{8}$');
  static final RegExp _australianMobileE164 = RegExp(r'^\+614\d{8}$');

  /// [input] in E.164, or null if it isn't a number a code can be texted to.
  ///
  /// Australian mobiles can be typed the local way (`0412 345 678`); any
  /// other number needs its country code (`+64 21 123 4567`).
  static String? toE164(String? input) {
    final text = (input ?? '').trim().replaceAll(_separators, '');
    if (text.isEmpty) return null;
    if (_international.hasMatch(text)) return text;
    if (_australianMobileLocal.hasMatch(text)) return '+61${text.substring(1)}';
    if (_australianMobileNoPlus.hasMatch(text)) return '+$text';
    return null;
  }

  /// Whether [a] and [b] are the same number, however each was typed.
  static bool same(String? a, String? b) {
    final first = toE164(a);
    return first != null && first == toE164(b);
  }

  /// [phone] the way people write it: `0412 345 678` for an Australian
  /// mobile, otherwise unchanged.
  static String display(String? phone) {
    final text = (phone ?? '').trim();
    final e164 = toE164(text);
    if (e164 == null || !_australianMobileE164.hasMatch(e164)) return text;
    final local = '0${e164.substring(3)}';
    return '${local.substring(0, 4)} ${local.substring(4, 7)} ${local.substring(7)}';
  }
}
