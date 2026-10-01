import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/presentation/map_badges.dart';

void main() {
  // Mapbox's addStyleImage decodes the bytes as an image file; raw pixels
  // made Android's BitmapFactory return null and the map's setup throw.
  test('every badge ships as a 150×150 PNG', () {
    const pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (final id in MapBadges.all) {
      final bytes = File('assets/map_badges/$id.png').readAsBytesSync();
      expect(bytes.sublist(0, 8), pngSignature, reason: id);
      // IHDR width and height, big-endian, right after the signature.
      final header = ByteData.sublistView(bytes, 16, 24);
      expect(header.getUint32(0), 150, reason: '$id width');
      expect(header.getUint32(4), 150, reason: '$id height');
    }
  });
}
