/// Static choices offered while creating or editing a service.
abstract final class ServiceCatalog {
  /// Quick-pick categories shown as chips under the category field. Providers
  /// can still type any category of their own.
  static const List<String> categorySuggestions = [
    'Hair',
    'Colour',
    'Nails',
    'Lashes & Brows',
    'Makeup',
    'Skin & Facials',
    'Waxing',
    'Massage',
  ];

  /// Duration presets, in minutes, offered as chips.
  static const List<int> durationPresets = [15, 30, 45, 60, 90, 120];

  /// Bounds accepted for a custom duration, in minutes.
  static const int minDurationMinutes = 5;
  static const int maxDurationMinutes = 600;

  /// Highest price accepted for a single service, in AUD.
  static const double maxPrice = 10000;

  static const int maxNameLength = 80;
  static const int maxCategoryLength = 40;
  static const int maxDescriptionLength = 1500;
}

/// A service description split into free text and a "what's included" list.
///
/// Services have a single `description` column, so the inclusions a provider
/// writes as bullet lines (`• Pre-wash`, `- Blow-dry`, `* Treatment`) are
/// stored inline and pulled back out for display.
class ServiceDescription {
  const ServiceDescription({required this.summary, required this.included});

  /// Bullet written by the editor's "add bullet" shortcut.
  static const String bullet = '• ';

  static final RegExp _bulletLine = RegExp(r'^\s*[•\-*]\s+(.+)$');

  /// Non-bullet text, with blank lines collapsed.
  final String summary;

  /// One entry per bullet line, in order.
  final List<String> included;

  factory ServiceDescription.parse(String description) {
    final summary = <String>[];
    final included = <String>[];
    for (final line in description.split('\n')) {
      final match = _bulletLine.firstMatch(line);
      if (match != null) {
        included.add(match.group(1)!.trim());
      } else if (line.trim().isNotEmpty) {
        summary.add(line.trim());
      }
    }
    return ServiceDescription(summary: summary.join('\n'), included: included);
  }
}
