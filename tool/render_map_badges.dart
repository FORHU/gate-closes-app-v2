// Renders assets/map_badges/*.svg to PNGs at 3x (150×150) for the map.
//
// Mapbox's addStyleImage decodes encoded image bytes (BitmapFactory /
// UIImage), so the app ships PNGs instead of rasterizing SVGs at runtime,
// which also keeps GPU readback off low-end devices.
//
// Run after changing a badge SVG:
//   flutter test tool/render_map_badges.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _ids = [
  'badge-terminal-echo',
  'badge-parallel-soul',
  'badge-destination-thread',
  'badge-baton-touch',
  'badge-cluster',
  'badge-offer',
];

/// Logical badge size (Expo's 50×50) times the shipped scale.
const int _px = 50 * 3;

void main() {
  testWidgets('render map badge PNGs', (tester) async {
    await tester.runAsync(() async {
      for (final id in _ids) {
        final svg = File('assets/map_badges/$id.svg').readAsStringSync();
        final info = await vg.loadPicture(SvgStringLoader(svg), null);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
          ..scale(_px / info.size.width, _px / info.size.height)
          ..drawPicture(info.picture);
        final image = await recorder.endRecording().toImage(_px, _px);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('assets/map_badges/$id.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
        image.dispose();
        info.picture.dispose();
      }
    });
  });
}
