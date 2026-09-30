/// Returns the first whitespace-separated token of [name], or `null` when the
/// name is missing or blank.
String? firstNameFrom(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}
