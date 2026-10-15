// Renders the app's SVG art to PNGs:
//  - assets/map_badges/*.svg at 3x (150×150) for the map.
//  - assets/avatars/*.svg at 3x (288×288) for the preset profile avatars.
//
// Mapbox's addStyleImage decodes encoded image bytes (BitmapFactory /
// UIImage), so the app ships PNGs instead of rasterizing SVGs at runtime,
// which also keeps GPU readback off low-end devices. The avatars reuse the
// same path so flutter_svg stays a dev-only dependency.
//
// Run after changing a badge or avatar SVG:
//   flutter test tool/render_map_badges.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/shared/widgets/user_avatar.dart';

const _badgeIds = [
  'badge-terminal-echo',
  'badge-parallel-soul',
  'badge-destination-thread',
  'badge-baton-touch',
  'badge-cluster',
];

/// Logical badge size (Expo's 50×50) times the shipped scale.
const int _badgePx = 50 * 3;

/// Avatar art is drawn on a 96×96 grid; shipped at 3x.
const int _avatarPx = 96 * 3;

Future<void> _render(String dir, String id, int px) async {
  final svg = File('$dir/$id.svg').readAsStringSync();
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..scale(px / info.size.width, px / info.size.height)
    ..drawPicture(info.picture);
  final image = await recorder.endRecording().toImage(px, px);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$dir/$id.png').writeAsBytesSync(png!.buffer.asUint8List());
  image.dispose();
  info.picture.dispose();
}

void main() {
  testWidgets('render map badge PNGs', (tester) async {
    await tester.runAsync(() async {
      for (final id in _badgeIds) {
        await _render('assets/map_badges', id, _badgePx);
      }
    });
  });

  testWidgets('render preset avatar PNGs', (tester) async {
    await tester.runAsync(() async {
      for (final id in presetAvatars.keys) {
        await _render('assets/avatars', id, _avatarPx);
      }
    });
  });
}
