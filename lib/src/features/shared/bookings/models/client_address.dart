/// Australian states and territories, for address entry.
enum AustralianState {
  qld('QLD', 'Queensland'),
  nsw('NSW', 'New South Wales'),
  vic('VIC', 'Victoria'),
  tas('TAS', 'Tasmania'),
  sa('SA', 'South Australia'),
  wa('WA', 'Western Australia'),
  nt('NT', 'Northern Territory'),
  act('ACT', 'Australian Capital Territory');

  const AustralianState(this.code, this.label);

  final String code;
  final String label;

  static AustralianState? fromCode(String? code) {
    final upper = code?.trim().toUpperCase();
    for (final state in values) {
      if (state.code == upper) return state;
    }
    return null;
  }
}

/// A street address where a mobile provider meets the client.
///
/// Mirrors the server's validation and formatting (see
/// `private.format_client_address`), so what the client reviews is exactly
/// what the provider receives.
class ClientAddress {
  const ClientAddress({
    required this.line1,
    this.unit,
    required this.suburb,
    required this.state,
    required this.postcode,
  });

  /// Street number and name, e.g. `12 Smith St`.
  final String line1;

  /// Unit, apartment or level, e.g. `Unit 4`.
  final String? unit;
  final String suburb;
  final AustralianState state;
  final String postcode;

  static const int maxLine1Length = 120;
  static const int maxUnitLength = 30;
  static const int maxSuburbLength = 60;

  static final RegExp _postcode = RegExp(r'^\d{4}$');

  factory ClientAddress.fromJson(Map<String, dynamic> json) => ClientAddress(
        line1: (json['line1'] as String? ?? '').trim(),
        unit: (json['unit'] as String?)?.trim(),
        suburb: (json['suburb'] as String? ?? '').trim(),
        state: AustralianState.fromCode(json['state'] as String?) ?? AustralianState.qld,
        postcode: (json['postcode'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toJson() => {
        'line1': line1.trim(),
        if (_unit != null) 'unit': _unit,
        'suburb': suburb.trim(),
        'state': state.code,
        'postcode': postcode.trim(),
      };

  String? get _unit {
    final value = unit?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// `Unit 4, 12 Smith St, Southport QLD 4215`.
  String get formatted =>
      [?_unit, line1.trim(), '${suburb.trim()} ${state.code} ${postcode.trim()}'].join(', ');

  /// What to look up when locating the address. The unit is left out; it
  /// doesn't change where the building is and can confuse geocoders.
  String get geocodingQuery => '${line1.trim()}, ${suburb.trim()} ${state.code} ${postcode.trim()}, Australia';

  bool get isComplete =>
      validateLine1(line1) == null && validateSuburb(suburb) == null && validatePostcode(postcode) == null &&
      validateUnit(unit) == null;

  static String? validateLine1(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 3) return 'Enter the street number and name';
    if (text.length > maxLine1Length) return 'Keep the street address under $maxLine1Length characters';
    return null;
  }

  static String? validateUnit(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > maxUnitLength) return 'Keep this under $maxUnitLength characters';
    return null;
  }

  static String? validateSuburb(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2) return 'Enter your suburb';
    if (text.length > maxSuburbLength) return 'Keep the suburb under $maxSuburbLength characters';
    return null;
  }

  static String? validatePostcode(String? value) {
    if (!_postcode.hasMatch(value?.trim() ?? '')) return 'Enter a 4-digit postcode';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ClientAddress &&
      other.line1.trim() == line1.trim() &&
      other._unit == _unit &&
      other.suburb.trim().toLowerCase() == suburb.trim().toLowerCase() &&
      other.state == state &&
      other.postcode.trim() == postcode.trim();

  @override
  int get hashCode => Object.hash(line1.trim(), _unit, suburb.trim().toLowerCase(), state, postcode.trim());
}
