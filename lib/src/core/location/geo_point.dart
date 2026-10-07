import 'dart:typed_data';

/// A WGS84 coordinate.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite && longitude.isFinite && latitude.abs() <= 90 && longitude.abs() <= 180;

  /// Inside the bounding box of Australia (mainland and Tasmania), to catch
  /// an address that matched somewhere overseas.
  bool get isInAustralia => latitude >= -44.5 && latitude <= -9 && longitude >= 112 && longitude <= 154.5;

  /// GeoJSON order: `[longitude, latitude]`.
  List<double> toGeoJsonCoordinates() => [longitude, latitude];

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// Wire formats for PostGIS point columns (e.g. `profiles.coordinates`).
abstract final class PostgisPoint {
  /// Extended WKT accepted when writing a `geography(Point, 4326)` column.
  ///
  /// GeoJSON is *not* accepted by PostGIS's type input, so writes must use
  /// this form.
  static String toEwkt(GeoPoint point) => 'SRID=4326;POINT(${point.longitude} ${point.latitude})';

  /// Reads a point column as PostgREST returns it: hex-encoded EWKB (its
  /// default for geography columns, e.g. `0101000020E6100000…`) or a GeoJSON
  /// object. Returns null for anything that isn't a valid 2D point.
  static GeoPoint? parse(Object? value) {
    if (value is Map) return _fromGeoJson(value);
    if (value is String) return _fromHexEwkb(value);
    return null;
  }

  static GeoPoint? _fromGeoJson(Map<dynamic, dynamic> json) {
    final coordinates = json['coordinates'];
    if (json['type'] != 'Point' || coordinates is! List || coordinates.length < 2) return null;
    final lng = coordinates[0];
    final lat = coordinates[1];
    if (lng is! num || lat is! num) return null;
    final point = GeoPoint(latitude: lat.toDouble(), longitude: lng.toDouble());
    return point.isValid ? point : null;
  }

  static const int _sridFlag = 0x20000000;
  static const int _zFlag = 0x80000000;
  static const int _mFlag = 0x40000000;
  static const int _pointType = 1;

  static GeoPoint? _fromHexEwkb(String hex) {
    if (hex.length < 42 || hex.length.isOdd) return null;
    final Uint8List bytes;
    try {
      bytes = Uint8List.fromList([
        for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
      ]);
    } on FormatException {
      return null;
    }

    final data = ByteData.sublistView(bytes);
    final endian = switch (bytes[0]) {
      0 => Endian.big,
      1 => Endian.little,
      _ => null,
    };
    if (endian == null) return null;

    final type = data.getUint32(1, endian);
    if (type & 0x0FFFFFFF != _pointType) return null;
    var offset = 5;
    if (type & _sridFlag != 0) offset += 4;
    final dimensions = 2 + (type & _zFlag != 0 ? 1 : 0) + (type & _mFlag != 0 ? 1 : 0);
    if (bytes.length < offset + dimensions * 8) return null;

    final point = GeoPoint(
      longitude: data.getFloat64(offset, endian),
      latitude: data.getFloat64(offset + 8, endian),
    );
    return point.isValid ? point : null;
  }
}
