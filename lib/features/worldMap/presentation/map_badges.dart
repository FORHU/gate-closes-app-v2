import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Pin badges for the map's symbol layers — the Expo app's
/// `components/shared/badges/*` SVGs, converted to `assets/map_badges/`.
/// Image ids match Expo so the layer expressions read the same.
abstract final class MapBadges {
  static const terminalEcho = 'badge-terminal-echo';
  static const parallelSoul = 'badge-parallel-soul';
  static const destinationThread = 'badge-destination-thread';
  static const batonTouch = 'badge-baton-touch';
  static const cluster = 'badge-cluster';

  /// Offers (ads, vouchers): not an echo, so its own orange tag badge.
  static const offer = 'badge-offer';

  static const List<String> all = [
    terminalEcho,
    parallelSoul,
    destinationThread,
    batonTouch,
    cluster,
    offer,
  ];

  /// Scale the PNGs are rendered at: 150×150 px for Expo's 50×50 badge.
  static const double _scale = 3;
  static const int _px = 150;

  /// Registers every badge on [style].
  ///
  /// The plugin decodes the bytes as an image file (Android BitmapFactory,
  /// iOS UIImage), so these must be PNGs, not raw pixels. They're rendered
  /// ahead of time by `tool/render_map_badges.dart`.
  static Future<void> addTo(StyleManager style) async {
    for (final id in all) {
      final png = await rootBundle.load('assets/map_badges/$id.png');
      await style.addStyleImage(
        id,
        _scale,
        MbxImage(width: _px, height: _px, data: png.buffer.asUint8List()),
        false,
        [],
        [],
        null,
      );
    }
  }
}
