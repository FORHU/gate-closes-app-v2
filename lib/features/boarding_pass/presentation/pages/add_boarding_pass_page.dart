import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gate_closes/core/utils/context_extensions.dart';
import 'package:gate_closes/features/boarding_pass/presentation/widgets/boarding_pass_scanner_sheet.dart';
import 'package:gate_closes/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:gate_closes/routes/route_names.dart';
import 'package:go_router/go_router.dart';

/// Full screen boarding pass scanning / manual entry page.
/// Used in onboarding flow and settings flight ticket editor.
class AddBoardingPassPage extends ConsumerWidget {
  const AddBoardingPassPage({
    this.initialTicket,
    this.onCompletedRoute,
    super.key,
  });

  final FlightTicketEntity? initialTicket;
  final String? onCompletedRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          initialTicket != null ? 'Edit Flight Ticket' : 'Add Boarding Pass',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: colors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: BoardingPassScannerSheet(
          initialTicket: initialTicket,
          completeButtonText: 'SAVE & PROCEED',
          onCompleted: () {
            if (onCompletedRoute != null) {
              context.go(onCompletedRoute!);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.feed);
            }
          },
        ),
      ),
    );
  }
}
