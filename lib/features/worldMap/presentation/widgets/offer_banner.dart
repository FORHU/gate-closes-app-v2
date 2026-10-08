import 'package:flutter/material.dart';
import 'package:gate_closes/features/worldMap/domain/entities/map_offer.dart';
import 'package:gate_closes/features/worldMap/presentation/widgets/offer_sheet.dart';
import 'package:gate_closes/theme/tokens/colors.dart';
import 'package:gate_closes/theme/tokens/spacing.dart';

/// The map is always dark, so its sheets use the dark palette whatever
/// the app theme.
const GateColors _kUi = GateColors.dark;

/// The airport's offer card, as a small banner over the bottom of the map
/// (the app has no airport sheet to hold it). Tap to open, × to hide it
/// for the rest of the session.
class OfferBanner extends StatelessWidget {
  const OfferBanner({
    required this.offer,
    required this.onOpen,
    required this.onDismiss,
    super.key,
  });

  final MapOffer offer;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kUi.glassStrong,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            0,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Image.asset(
                'assets/map_badges/badge-offer.png',
                width: 36,
                height: 36,
              ),
              AppSpacing.h(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${OfferSheet.kindLabel(offer.kind)} at '
                      '${offer.airportIata}',
                      style: const TextStyle(
                        color: kOfferAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _kUi.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hide offer',
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, color: _kUi.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
