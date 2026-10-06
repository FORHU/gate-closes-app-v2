import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// Accent for offers: the orange of their map badge.
const kOfferAccent = Color(0xFFF2994A);

/// One offer (from its map pin or the offer banner): image, text, its
/// button link, and Claim for offers with a reward (vouchers). The page
/// passes the actions so this stays a plain widget.
class OfferSheet extends StatefulWidget {
  const OfferSheet({
    required this.offer,
    required this.onOpenLink,
    required this.onClaim,
    super.key,
  });

  final MapOffer offer;
  final Future<void> Function() onOpenLink;
  final Future<Either<Failure, OfferReward>> Function() onClaim;

  static Future<void> show(
    BuildContext context, {
    required MapOffer offer,
    required Future<void> Function() onOpenLink,
    required Future<Either<Failure, OfferReward>> Function() onClaim,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfferSheet(
        offer: offer,
        onOpenLink: onOpenLink,
        onClaim: onClaim,
      ),
    );
  }

  /// "voucher" → "Voucher", "lounge_pass" → "Lounge pass".
  static String kindLabel(String kind) {
    final words = kind.replaceAll(RegExp('[_-]+'), ' ').trim();
    if (words.isEmpty) return 'Offer';
    return words[0].toUpperCase() + words.substring(1);
  }

  @override
  State<OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<OfferSheet> {
  bool _claiming = false;
  OfferReward? _reward;
  String? _error;

  Future<void> _claim() async {
    setState(() {
      _claiming = true;
      _error = null;
    });
    final result = await widget.onClaim();
    if (!mounted) return;
    setState(() {
      _claiming = false;
      result.match((f) => _error = f.message, (r) => _reward = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final link = offer.ctaUrl;
    return Material(
      color: const Color(0xFF111418),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AppSpacing.v(AppSpacing.md),
              if (offer.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: offer.imageUrl!,
                      fit: BoxFit.cover,
                      // A broken image just isn't shown.
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                AppSpacing.v(AppSpacing.md),
              ],
              Text(
                '${OfferSheet.kindLabel(offer.kind)} · ${offer.airportIata}',
                style: const TextStyle(
                  color: kOfferAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.v(AppSpacing.xs),
              Text(
                offer.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (offer.body != null) ...[
                AppSpacing.v(AppSpacing.sm),
                Text(
                  offer.body!,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
              for (final MapEntry(:key, :value) in offer.details.entries)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '${OfferSheet.kindLabel(key)}: $value',
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              if (offer.endsAt != null) ...[
                AppSpacing.v(AppSpacing.sm),
                Text(
                  'Until ${MaterialLocalizations.of(context).formatMediumDate(
                    offer.endsAt!.toLocal(),
                  )}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
              AppSpacing.v(AppSpacing.lg),
              if (_reward != null)
                _RewardBox(reward: _reward!)
              else if (offer.claimable)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kOfferAccent,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _claiming ? null : _claim,
                  child: Text(_claiming ? 'Claiming…' : 'Claim'),
                ),
              if (_error != null) ...[
                AppSpacing.v(AppSpacing.sm),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFF8A80)),
                ),
              ],
              if (link != null) ...[
                AppSpacing.v(AppSpacing.sm),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: widget.onOpenLink,
                  child: Text(offer.ctaLabel ?? 'Open'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The claimed reward: its code to copy, then any other fields.
class _RewardBox extends StatelessWidget {
  const _RewardBox({required this.reward});

  final OfferReward reward;

  @override
  Widget build(BuildContext context) {
    final code = reward.code;
    final others = reward.fields.entries.where((e) => e.key != 'code');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: kOfferAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOfferAccent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'Claimed!',
            style: TextStyle(color: kOfferAccent, fontWeight: FontWeight.w600),
          ),
          if (code != null) ...[
            AppSpacing.v(AppSpacing.sm),
            SelectableText(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: code)));
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('Code copied')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy code'),
            ),
          ],
          for (final MapEntry(:key, :value) in others)
            Text(
              '${OfferSheet.kindLabel(key)}: $value',
              style: const TextStyle(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
