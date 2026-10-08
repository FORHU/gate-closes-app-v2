import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/worldMap/presentation/controllers/map_lighting_controller.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Settings → Map Lighting (Expo `settings/map-lighting.tsx`).
class MapLightingPage extends ConsumerWidget {
  const MapLightingPage({super.key});

  static const Map<MapLightingMode, (String, String)> _modes = {
    MapLightingMode.realtime: (
      'Realtime Lighting',
      'Dusk through the day and night after dark, by your device time.',
    ),
    MapLightingMode.fixed: (
      'Static Lighting',
      'Locks the map to a chosen lighting preset until you change it again.',
    ),
  };

  static const Map<MapTimeOfDay, (String, String)> _presets = {
    MapTimeOfDay.dawn: (
      'Dawn',
      'Early warm light with low contrast and a softer horizon.',
    ),
    MapTimeOfDay.day: (
      'Day',
      'Bright daylight for the clearest map presentation.',
    ),
    MapTimeOfDay.dusk: (
      'Dusk',
      'The amber terminal look that blends best with the current shell.',
    ),
    MapTimeOfDay.night: (
      'Night',
      'Cooler low-light rendering for a darker atmosphere.',
    ),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final lighting = ref.watch(mapLightingControllerProvider);
    final controller = ref.read(mapLightingControllerProvider.notifier);
    final current = lighting.presetAt(DateTime.now());

    Widget section(String label) => Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: const Text('Map Lighting'),
      ),
      body: ListView(
        padding: AppSpacing.edgeInsetsMd,
        children: [
          Text(
            'Currently showing: ${_presets[current]!.$1}',
            style: TextStyle(color: colors.textSecondary),
          ),
          section('Lighting Mode'),
          for (final MapEntry(key: mode, value: (title, description))
              in _modes.entries)
            _OptionTile(
              title: title,
              description: description,
              selected: lighting.mode == mode,
              onTap: () => unawaited(controller.setMode(mode)),
            ),
          if (lighting.mode == MapLightingMode.fixed) ...[
            section('Static Preset'),
            for (final MapEntry(key: preset, value: (title, description))
                in _presets.entries)
              _OptionTile(
                title: title,
                description: description,
                selected: lighting.fixedPreset == preset,
                swatch: preset.tint.withValues(alpha: 1),
                onTap: () => unawaited(controller.setFixedPreset(preset)),
              ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.swatch,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? colors.accent : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.edgeInsetsMd,
            child: Row(
              children: [
                if (swatch != null) ...[
                  CircleAvatar(radius: 10, backgroundColor: swatch),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected ? colors.accent : colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: colors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
