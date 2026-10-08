import 'dart:collection';

/// Which map a phone gets (the device ladder). A phone that can't render a
/// map at all is handled before this, by the map render guard.
enum MapTier {
  /// dark-v11 with Chumme's palette, flat heat; for weak phones.
  lite,

  /// Mapbox Standard: the lit 3D city, light beams, lit airport buildings.
  standard,
}

/// What the phone reports about itself; null when unknown.
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.is64Bit,
    this.totalRamMb,
    this.lowRam,
    this.sdk,
  });

  final bool is64Bit;
  final int? totalRamMb;

  /// Android's own low-RAM device flag.
  final bool? lowRam;

  /// Android API level.
  final int? sdk;
}

/// Picks the map for a phone: the 3D map only where it is likely to run
/// well, the lite map on any weak spot.
class MapTierPolicy {
  MapTierPolicy._();

  /// Memory as Android reports it; a phone sold as "6 GB" reports ~5.5.
  static const int minRamMb = 5000;

  /// Android 10.
  static const int minSdk = 29;

  /// [measuredTooSlow]: the 3D map was measured too slow on this phone
  /// before (FrameBudgetMonitor), so it stays lite.
  static MapTier decide(
    DeviceCapabilities device, {
    bool measuredTooSlow = false,
  }) {
    final ram = device.totalRamMb;
    final sdk = device.sdk;
    final weak = !device.is64Bit ||
        device.lowRam == true ||
        (ram != null && ram < minRamMb) ||
        (sdk != null && sdk < minSdk) ||
        measuredTooSlow;
    return weak ? MapTier.lite : MapTier.standard;
  }
}

/// Watches frame times on the 3D map and says when the phone is clearly
/// too slow for it: over the last [window] frames, at least [maxSlowShare]
/// of them over [slowFrame] (below ~30 fps). Occasional slow frames, like
/// tiles loading during a fast pan, don't count against a phone.
class FrameBudgetMonitor {
  FrameBudgetMonitor({
    this.window = 300,
    this.slowFrame = const Duration(milliseconds: 33),
    this.maxSlowShare = 0.5,
  });

  final int window;
  final Duration slowFrame;
  final double maxSlowShare;

  final Queue<bool> _frames = Queue<bool>();
  int _slow = 0;

  /// Records one frame; true once the latest full window is too slow.
  bool add(Duration frame) {
    final isSlow = frame > slowFrame;
    _frames.addLast(isSlow);
    if (isSlow) _slow++;
    if (_frames.length > window && _frames.removeFirst()) _slow--;
    return _frames.length == window && _slow >= window * maxSlowShare;
  }
}
