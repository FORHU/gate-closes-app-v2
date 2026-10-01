import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Last successful map data on disk, so the map still shows boundaries and
/// pins offline (Expo `airportBoundariesDiskCache` / `mapMarkerDiskCache`).
abstract class MapDiskCache {
  Future<Map<String, dynamic>?> read(String name);
  Future<void> write(String name, Map<String, dynamic> json);
}

class FileMapDiskCache implements MapDiskCache {
  const FileMapDiskCache();

  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/map_cache_$name.json');
  }

  @override
  Future<Map<String, dynamic>?> read(String name) async {
    try {
      final file = await _file(name);
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } on Object catch (_) {
      return null; // A missing or corrupt cache is just a cache miss.
    }
  }

  @override
  Future<void> write(String name, Map<String, dynamic> json) async {
    try {
      final file = await _file(name);
      // Write-then-rename so a crash mid-write never leaves a torn file.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(jsonEncode(json), flush: true);
      await tmp.rename(file.path);
    } on Object catch (_) {
      // Caching is best-effort.
    }
  }
}

final mapDiskCacheProvider = Provider<MapDiskCache>(
  (ref) => const FileMapDiskCache(),
);
