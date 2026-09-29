import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/airport/domain/entities/airport_entity.dart';
import 'package:gate_closes/features/airport/presentation/controllers/airport_controller.dart';
import 'package:gate_closes/shared/widgets/glass_card.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Modal bottom sheet for searching and selecting an airport.
/// Mirrors `AirportPickerModal.tsx` in the React Native reference app.
class AirportPickerSheet extends ConsumerStatefulWidget {
  const AirportPickerSheet({
    required this.title,
    this.initialQuery = '',
    this.excludeCode,
    super.key,
  });

  final String title;
  final String initialQuery;
  final String? excludeCode;

  static Future<AirportEntity?> show(
    BuildContext context, {
    required String title,
    String initialQuery = '',
    String? excludeCode,
  }) {
    return showModalBottomSheet<AirportEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AirportPickerSheet(
        title: title,
        initialQuery: initialQuery,
        excludeCode: excludeCode,
      ),
    );
  }

  @override
  ConsumerState<AirportPickerSheet> createState() => _AirportPickerSheetState();
}

class _AirportPickerSheetState extends ConsumerState<AirportPickerSheet> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;
  List<AirportEntity> _results = const [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery.isNotEmpty) {
      unawaited(_performSearch(widget.initialQuery));
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = const [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_performSearch(trimmed));
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    final repo = ref.read(airportRepositoryProvider);
    final res = await repo.searchAirports(query);
    if (!mounted) return;

    res.fold(
      (_) => setState(() {
        _results = const [];
        _isLoading = false;
      }),
      (airports) {
        final filtered = widget.excludeCode != null
            ? airports.where((a) => a.iata != widget.excludeCode).toList()
            : airports;
        setState(() {
          _results = filtered;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: colors.accent.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search airport by name, IATA, or city...',
                hintStyle: TextStyle(color: colors.textMuted),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: colors.accent,
                ),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colors.accent),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Loading or results
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_results.isEmpty && _searchController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'No airports found for "${_searchController.text.trim()}".',
                  style: TextStyle(color: colors.textMuted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, index) {
                  final airport = _results[index];
                  return GlassCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          airport.iata,
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      title: Text(
                        airport.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        airport.countryCode != null
                            ? 'Country: ${airport.countryCode}'
                            : (airport.icao ?? ''),
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.check_circle_outline_rounded,
                        color: colors.textMuted,
                        size: 20,
                      ),
                      onTap: () => Navigator.of(context).pop(airport),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
