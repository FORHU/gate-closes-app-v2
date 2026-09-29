import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform guard for native features (like Mapbox, Camera, etc.)
/// Prevents crashes on desktop (Windows/Linux/macOS) or web.
class PlatformSupport {
  PlatformSupport._();

  static bool get isMapboxSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }
}
