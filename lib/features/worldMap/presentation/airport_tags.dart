import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_echo_count.dart';
import 'package:gate_closes/features/worldMap/domain/entities/airport_point.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/typography.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// The map is always dark, so its overlays use the dark palette whatever
/// the app theme.
const GateColors _kUi = GateColors.dark;

/// Airport tags for the zoomed-out map, as Chumme's HUD callouts: a glass
/// plate with the airport's name and echo count, a glowing leader line down
/// to a ring on the airport.
///
/// Each tag is drawn once into an image and handed to Mapbox, which places
/// it as a map symbol at the airport. So it moves with the map frame by
/// frame (a Flutter overlay re-projected per camera change lagged behind a
/// swipe) and hides round the far side of the globe. Every airport with
/// echoes keeps its tag; where two overlap the busier is drawn on top.
abstract final class AirportTags {
  /// Image id of [iata]'s tag; the symbol layer reads it per feature.
  static String imageId(String iata) => 'airport-tag-$iata';

  /// `icon-image` for the symbol layer over the airport points.
  static const List<Object> iconImage = [
    'concat',
    'airport-tag-',
    ['get', 'airportIata'],
  ];

  /// The ring sits this far above the image's bottom edge; the layer's
  /// `icon-offset` moves the image down by it so the ring is on the airport.
  static const double ringInset = 8;

  static const double _plateHeight = 40;
  static const double _leader = 40;
  static const double _ringRadius = 6;
  static const double _margin = 6;

  /// Pixels per point the images are drawn at.
  static const double _scale = 3;

  /// The text each airport's current image was drawn with, so a tag is only
  /// redrawn when its name or count changes. Cleared when the style reloads
  /// (its images go with it).
  static final Map<String, String> _drawn = {};

  static void forgetImages() => _drawn.clear();

  /// Draws and registers the tags of [counts] that are new or changed.
  static Future<void> addTo(
    StyleManager style,
    List<AirportEchoCount> counts,
  ) async {
    for (final a in counts) {
      final text = '${title(a)}\n${meta(a)}';
      if (_drawn[a.airportIata] == text) continue;
      final image = await _render(title(a), meta(a));
      await style.addStyleImage(
        imageId(a.airportIata),
        _scale,
        image,
        false,
        [],
        [],
        null,
      );
      _drawn[a.airportIata] = text;
    }
  }

  /// The glass plate of the quiet airports' tags (no echoes): one image
  /// for all of them, stretched by Mapbox around each one's text
  /// (`icon-text-fit`). Thousands of per-airport images would not fit in a
  /// phone's memory; this stays one.
  static const plateImage = 'airport-tag-plate';

  /// Registers [plateImage]: a rounded glass square whose middle stretches
  /// and whose content box (the text area) keeps 10 pt / 6 pt of padding.
  static Future<void> addPlate(StyleManager style) async {
    const side = 48.0;
    const corner = 10.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    final rounded = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0.5, 0.5, side - 1, side - 1),
      const Radius.circular(corner),
    );
    canvas
      ..drawRRect(rounded, Paint()..color = _kUi.glassStrong)
      ..drawRRect(
        rounded,
        Paint()
          ..color = _kUi.accent.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    const px = (side * _scale) ~/ 1;
    final image = await recorder.endRecording().toImage(px, px);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    // Stretch only between the rounded corners, so they keep their shape.
    const from = (corner + 2) * _scale;
    const to = (side - corner - 2) * _scale;
    await style.addStyleImage(
      plateImage,
      _scale,
      MbxImage(width: px, height: px, data: png!.buffer.asUint8List()),
      false,
      [ImageStretches(first: from, second: to)],
      [ImageStretches(first: from, second: to)],
      ImageContent(
        left: 10 * _scale,
        top: 6 * _scale,
        right: (side - 10) * _scale,
        bottom: (side - 6) * _scale,
      ),
    );
  }

  /// The airport's name without "(International) Airport", in capitals.
  static String title(AirportEchoCount a) {
    final name = a.airportName?.trim();
    if (name == null || name.isEmpty) return a.airportIata;
    return AirportPoint.shortName(name);
  }

  static String meta(AirportEchoCount a) =>
      '${a.airportIata} · ${a.count} ${a.count == 1 ? 'ECHO' : 'ECHOES'}';

  static TextPainter _text(String s, TextStyle style, double maxWidth) =>
      TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  static Future<MbxImage> _render(String title, String meta) async {
    const maxText = 196.0;
    final titlePainter = _text(
      title,
      TextStyle(
        fontFamily: AppTypography.fontFamily,
        color: _kUi.textPrimary,
        fontSize: 11.5,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
      maxText,
    );
    final metaPainter = _text(
      meta,
      TextStyle(
        fontFamily: AppTypography.fontFamily,
        color: _kUi.accent,
        fontSize: 9.5,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
      maxText,
    );
    final plateWidth =
        (20 + [titlePainter.width, metaPainter.width].reduce(_max))
            .clamp(84, 220)
            .toDouble();
    final width = plateWidth + 2 * _margin;
    const height = _margin + _plateHeight + _leader + ringInset + _ringRadius;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    final cx = width / 2;
    const ringY = height - ringInset;
    final plate = Rect.fromLTWH(_margin, _margin, plateWidth, _plateHeight);

    // Leader: a soft glow under a thin line, from the plate down to the ring.
    final accent = _kUi.accent;
    canvas
      ..drawLine(
        Offset(cx, plate.bottom),
        Offset(cx, ringY - _ringRadius),
        Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawLine(
        Offset(cx, plate.bottom),
        Offset(cx, ringY - _ringRadius),
        Paint()
          ..color = accent.withValues(alpha: 0.85)
          ..strokeWidth = 1.2,
      )
      ..drawCircle(
        Offset(cx, ringY),
        _ringRadius,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      )
      ..drawCircle(Offset(cx, ringY), 2, Paint()..color = accent);

    // Glass plate with a faint lime edge, then the two lines of text.
    final rounded = RRect.fromRectAndRadius(plate, const Radius.circular(10));
    canvas
      ..drawRRect(rounded, Paint()..color = _kUi.glassStrong)
      ..drawRRect(
        rounded,
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    final textTop = plate.top +
        (_plateHeight - titlePainter.height - metaPainter.height) / 2;
    titlePainter.paint(canvas, Offset(plate.left + 10, textTop));
    metaPainter.paint(
      canvas,
      Offset(plate.left + 10, textTop + titlePainter.height),
    );

    final px = (width * _scale).ceil();
    final py = (height * _scale).ceil();
    final image = await recorder.endRecording().toImage(px, py);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return MbxImage(width: px, height: py, data: png!.buffer.asUint8List());
  }

  static double _max(double a, double b) => a > b ? a : b;
}
