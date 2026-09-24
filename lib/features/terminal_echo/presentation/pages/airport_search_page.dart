import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/features/airport/domain/entities/airport_entity.dart';
import 'package:flutter_template/features/airport/presentation/controllers/airport_controller.dart';
import 'package:flutter_template/features/terminal_echo/presentation/controllers/terminal_echo_controller.dart';
import 'package:flutter_template/shared/widgets/glass_card.dart';
import 'package:flutter_template/theme/tokens/colors.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';
import 'package:go_router/go_router.dart';

class AirportSearchPage extends ConsumerStatefulWidget {
  const AirportSearchPage({super.key});

  @override
  ConsumerState<AirportSearchPage> createState() => _AirportSearchPageState();
}

class _AirportSearchPageState extends ConsumerState<AirportSearchPage> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  List<AirportEntity> _results = const [];
  bool _isLoading = false;

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

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      final repo = ref.read(airportRepositoryProvider);
      final res = await repo.searchAirports(trimmed);
      if (!mounted) return;

      res.fold(
        (_) => setState(() {
          _results = const [];
          _isLoading = false;
        }),
        (airports) => setState(() {
          _results = airports;
          _isLoading = false;
        }),
      );
    });
  }

  void _selectAirport(AirportEntity airport) {
    unawaited(
      ref
          .read(terminalEchoControllerProvider.notifier)
          .loadFeed(airport.iata),
    );
    context.pop(airport);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search airport or city...',
            hintStyle: TextStyle(color: colors.textMuted),
            border: InputBorder.none,
          ),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                _searchController.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: _buildContent(colors),
    );
  }

  Widget _buildContent(GateColors colors) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.flight_takeoff_rounded,
              size: 48,
              color: colors.textMuted,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Start typing to search an airport',
              style: TextStyle(color: colors.textMuted),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No airports found',
          style: TextStyle(color: colors.textMuted),
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.edgeInsetsMd,
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final airport = _results[index];
        return GlassCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: colors.accent.withValues(alpha: 0.15),
              child: Icon(Icons.flight_rounded, color: colors.accent, size: 18),
            ),
            title: Text(
              airport.name,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              [
                airport.iata,
                if (airport.countryCode != null) airport.countryCode!,
              ].join(' · '),
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
            ),
            onTap: () => _selectAirport(airport),
          ),
        );
      },
    );
  }
}
