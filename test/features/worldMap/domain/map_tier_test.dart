import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';

void main() {
  group('MapTierPolicy.decide', () {
    const strong = DeviceCapabilities(
      is64Bit: true,
      totalRamMb: 7300,
      lowRam: false,
      sdk: 33,
    );

    test('a strong phone gets the 3D map', () {
      expect(MapTierPolicy.decide(strong), MapTier.standard);
    });

    test('any weak spot means the lite map', () {
      const cases = {
        '32-bit': DeviceCapabilities(
          is64Bit: false,
          totalRamMb: 7300,
          lowRam: false,
          sdk: 33,
        ),
        'little RAM': DeviceCapabilities(
          is64Bit: true,
          totalRamMb: 3800,
          lowRam: false,
          sdk: 33,
        ),
        'Android low-RAM flag': DeviceCapabilities(
          is64Bit: true,
          totalRamMb: 7300,
          lowRam: true,
          sdk: 33,
        ),
        'old Android': DeviceCapabilities(
          is64Bit: true,
          totalRamMb: 7300,
          lowRam: false,
          sdk: 28,
        ),
      };
      for (final MapEntry(key: reason, value: device) in cases.entries) {
        expect(MapTierPolicy.decide(device), MapTier.lite, reason: reason);
      }
    });

    test('unknown capabilities are not held against a 64-bit phone', () {
      const unknown = DeviceCapabilities(is64Bit: true);
      expect(MapTierPolicy.decide(unknown), MapTier.standard);
    });

    test('a phone the map was too slow on stays lite', () {
      expect(
        MapTierPolicy.decide(strong, measuredTooSlow: true),
        MapTier.lite,
      );
    });
  });

  group('FrameBudgetMonitor', () {
    const fast = Duration(milliseconds: 12);
    const slow = Duration(milliseconds: 45);

    test('no verdict before the window is full', () {
      final monitor = FrameBudgetMonitor(window: 10);
      for (var i = 0; i < 9; i++) {
        expect(monitor.add(slow), isFalse);
      }
    });

    test('mostly slow frames over a full window: too slow', () {
      final monitor = FrameBudgetMonitor(window: 10);
      var verdict = false;
      for (var i = 0; i < 10; i++) {
        verdict = monitor.add(i < 4 ? fast : slow);
      }
      expect(verdict, isTrue);
    });

    test('occasional slow frames are fine', () {
      final monitor = FrameBudgetMonitor(window: 10);
      var verdict = false;
      for (var i = 0; i < 40; i++) {
        verdict = verdict || monitor.add(i % 4 == 0 ? slow : fast);
      }
      expect(verdict, isFalse);
    });

    test('judges only the latest window', () {
      final monitor = FrameBudgetMonitor(window: 10);
      for (var i = 0; i < 10; i++) {
        monitor.add(fast);
      }
      var verdict = false;
      for (var i = 0; i < 10; i++) {
        verdict = monitor.add(slow);
      }
      expect(verdict, isTrue);
    });
  });
}
