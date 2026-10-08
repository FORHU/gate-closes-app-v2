import 'dart:ffi';

import 'package:flutter/services.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_tier.dart';

/// Reads what the phone reports about itself for the map's device ladder,
/// from `MainActivity` on Android (`gate_closes/device`). Anything it can't
/// read is left unknown, which MapTierPolicy doesn't hold against a phone.
class DeviceCapabilitiesSource {
  const DeviceCapabilitiesSource();

  static const _channel = MethodChannel('gate_closes/device');

  Future<DeviceCapabilities> read() async {
    final abi = Abi.current();
    final is64Bit = abi != Abi.androidArm && abi != Abi.androidIA32;
    try {
      final info =
          await _channel.invokeMapMethod<String, Object?>('mapCapabilities');
      return DeviceCapabilities(
        is64Bit: is64Bit,
        totalRamMb: info?['totalRamMb'] as int?,
        lowRam: info?['lowRam'] as bool?,
        sdk: info?['sdk'] as int?,
      );
    } on Object {
      // iOS, tests, or an old build without the channel.
      return DeviceCapabilities(is64Bit: is64Bit);
    }
  }
}
