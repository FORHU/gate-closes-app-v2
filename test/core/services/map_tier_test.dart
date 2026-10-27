import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/services/map_tier.dart';

void main() {
  group('MapTierPolicy.decide', () {
    const strong = DeviceCapabilities(
      is64Bit: true,
      totalRamMb: 7300,
      lowRam: false,
      sdk: 33,
    );

    test('the 2D map by default, even on a strong phone', () {
      expect(MapTierPolicy.decide(strong), MapTier.lite);
    });

    test('a strong phone gets the 3D map once the user turns it on', () {
      expect(MapTierPolicy.decide(strong, wants3d: true), MapTier.standard);
    });

    test('any weak spot means the lite map, even with 3D turned on', () {
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
        expect(
          MapTierPolicy.decide(device, wants3d: true),
          MapTier.lite,
          reason: reason,
        );
      }
    });

    test('unknown capabilities are not held against a 64-bit phone', () {
      const unknown = DeviceCapabilities(is64Bit: true);
      expect(MapTierPolicy.decide(unknown, wants3d: true), MapTier.standard);
    });

    test('a phone the map was too slow on stays lite', () {
      expect(
        MapTierPolicy.decide(strong, measuredTooSlow: true, wants3d: true),
        MapTier.lite,
      );
    });
  });

  group('MapTierPolicy.why3dUnavailable', () {
    test('a capable phone has no reason', () {
      const strong = DeviceCapabilities(
        is64Bit: true,
        totalRamMb: 7300,
        lowRam: false,
        sdk: 33,
      );
      expect(MapTierPolicy.why3dUnavailable(strong), isNull);
      expect(
        MapTierPolicy.why3dUnavailable(strong, measuredTooSlow: true),
        No3dReason.measuredTooSlow,
      );
    });

    test('names the weak spot', () {
      const cases = {
        No3dReason.is32Bit: DeviceCapabilities(is64Bit: false),
        No3dReason.lowMemory: DeviceCapabilities(
          is64Bit: true,
          totalRamMb: 3800,
        ),
        No3dReason.oldAndroid: DeviceCapabilities(is64Bit: true, sdk: 28),
      };
      for (final MapEntry(key: reason, value: device) in cases.entries) {
        expect(MapTierPolicy.why3dUnavailable(device), reason);
      }
      expect(
        MapTierPolicy.why3dUnavailable(
          const DeviceCapabilities(is64Bit: true, lowRam: true),
        ),
        No3dReason.lowMemory,
      );
    });

    test('the realme RMX3231: 32-bit, 1.9 GB, low-RAM flag', () {
      const realme = DeviceCapabilities(
        is64Bit: false,
        totalRamMb: 1869,
        lowRam: true,
        sdk: 30,
      );
      expect(MapTierPolicy.why3dUnavailable(realme), No3dReason.is32Bit);
      expect(MapTierPolicy.decide(realme, wants3d: true), MapTier.lite);
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
