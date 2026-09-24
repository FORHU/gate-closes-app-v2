import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/utils/context_extensions.dart';
import 'package:flutter_template/features/airport/domain/entities/airport_entity.dart';
import 'package:flutter_template/features/boarding_pass/domain/heuristics/boarding_pass_ocr_heuristics.dart';
import 'package:flutter_template/features/boarding_pass/domain/parsers/bcbp_parser.dart';
import 'package:flutter_template/features/flight/domain/entities/flight_ticket_entity.dart';
import 'package:flutter_template/features/flight/presentation/controllers/flight_controller.dart';
import 'package:flutter_template/shared/widgets/airport_picker_sheet.dart';
import 'package:flutter_template/shared/widgets/app_button.dart';
import 'package:flutter_template/shared/widgets/glass_card.dart';
import 'package:flutter_template/shared/widgets/modern_text_field.dart';
import 'package:flutter_template/theme/tokens/spacing.dart';

/// Boarding pass camera scanner & manual confirmation sheet.
/// Matches `BoardingPassForm.tsx` from the Expo React Native app.
class BoardingPassScannerSheet extends ConsumerStatefulWidget {
  const BoardingPassScannerSheet({
    this.initialTicket,
    this.onCompleted,
    this.completeButtonText = 'PROCEED TO TERMINAL ECHO',
    super.key,
  });

  final FlightTicketEntity? initialTicket;
  final VoidCallback? onCompleted;
  final String completeButtonText;

  @override
  ConsumerState<BoardingPassScannerSheet> createState() =>
      _BoardingPassScannerSheetState();
}

class _BoardingPassScannerSheetState
    extends ConsumerState<BoardingPassScannerSheet> {
  final _flightNumberController = TextEditingController();
  final _manualOcrController = TextEditingController();

  AirportEntity? _fromAirport;
  AirportEntity? _toAirport;
  DateTime? _departureDateTime;
  DateTime? _returnDateTime;

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showOcrInput = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialTicket != null) {
      final t = widget.initialTicket!;
      _flightNumberController.text = t.flightNumber;
      _fromAirport = AirportEntity(
        id: '',
        iata: t.fromAirport,
        name: t.fromAirportName ?? t.fromAirport,
      );
      _toAirport = AirportEntity(
        id: '',
        iata: t.toAirport,
        name: t.toAirportName ?? t.toAirport,
      );
      _departureDateTime = t.departureDateTime;
      _returnDateTime = t.returnDateTime;
    }
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _manualOcrController.dispose();
    super.dispose();
  }

  void _applyExtracted({
    String? flightNumber,
    String? fromAirport,
    String? toAirport,
    String? departureDate,
  }) {
    if (flightNumber != null && flightNumber.isNotEmpty) {
      _flightNumberController.text = flightNumber;
    }
    if (fromAirport != null && fromAirport.isNotEmpty) {
      _fromAirport = AirportEntity(
        id: '',
        iata: fromAirport,
        name: fromAirport,
      );
    }
    if (toAirport != null && toAirport.isNotEmpty) {
      _toAirport = AirportEntity(
        id: '',
        iata: toAirport,
        name: toAirport,
      );
    }
    if (departureDate != null && departureDate.isNotEmpty) {
      final parsed = DateTime.tryParse(departureDate);
      if (parsed != null) {
        _departureDateTime = parsed;
        if (_returnDateTime == null || _returnDateTime!.isBefore(parsed)) {
          _returnDateTime = parsed.add(const Duration(days: 7));
        }
      }
    }
    setState(() {});
  }

  void _handleRawBarcode(String rawBarcode) {
    final parsed = BcbpParser.parse(rawBarcode);
    if (parsed != null) {
      _applyExtracted(
        flightNumber: '${parsed.airline}${parsed.flightNumber}'.trim(),
        fromAirport: parsed.fromAirport,
        toAirport: parsed.toAirport,
        departureDate: parsed.date,
      );
      setState(() => _errorMessage = null);
    } else {
      setState(() {
        _errorMessage = 'Invalid BCBP barcode format.';
      });
    }
  }

  void _handleOcrText(String text) {
    final guess = BoardingPassOcrHeuristics.guessFields(text);
    if (guess.flightNumber == null &&
        guess.fromAirport == null &&
        guess.toAirport == null) {
      setState(() {
        _errorMessage = 'Could not detect flight info from provided text.';
      });
      return;
    }

    _applyExtracted(
      flightNumber: guess.flightNumber,
      fromAirport: guess.fromAirport,
      toAirport: guess.toAirport,
      departureDate: guess.departureDateTime,
    );
    setState(() {
      _errorMessage = null;
      _showOcrInput = false;
    });
  }

  Future<void> _pickAirport(bool isFrom) async {
    final selected = await AirportPickerSheet.show(
      context,
      title: isFrom ? 'Select Departure Airport' : 'Select Arrival Airport',
      excludeCode: isFrom ? _toAirport?.iata : _fromAirport?.iata,
    );
    if (selected != null) {
      setState(() {
        if (isFrom) {
          _fromAirport = selected;
        } else {
          _toAirport = selected;
        }
      });
    }
  }

  Future<void> _pickDateTime(bool isDeparture) async {
    final initialDate = isDeparture
        ? (_departureDateTime ?? DateTime.now().add(const Duration(hours: 3)))
        : (_returnDateTime ??
            (_departureDateTime ?? DateTime.now())
                .add(const Duration(days: 7)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isDeparture) {
        _departureDateTime = combined;
        if (_returnDateTime != null && _returnDateTime!.isBefore(combined)) {
          _returnDateTime = combined.add(const Duration(days: 7));
        }
      } else {
        _returnDateTime = combined;
      }
    });
  }

  Future<void> _handleSubmit() async {
    final flightNum = _flightNumberController.text.trim();
    if (flightNum.isEmpty) {
      setState(() => _errorMessage = 'Flight number is required.');
      return;
    }
    if (_fromAirport == null) {
      setState(() => _errorMessage = 'Please select a departure airport.');
      return;
    }
    if (_toAirport == null) {
      setState(() => _errorMessage = 'Please select an arrival airport.');
      return;
    }
    if (_fromAirport!.iata == _toAirport!.iata) {
      setState(
        () => _errorMessage =
            'Origin and destination airports must be different.',
      );
      return;
    }
    if (_departureDateTime == null) {
      setState(() => _errorMessage = 'Please specify departure date/time.');
      return;
    }
    if (_returnDateTime == null) {
      setState(() => _errorMessage = 'Please specify return date/time.');
      return;
    }
    if (_returnDateTime!.isBefore(_departureDateTime!)) {
      setState(
        () => _errorMessage = 'Return date must be after departure date.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success =
        await ref.read(flightControllerProvider.notifier).saveFlightTicket(
              flightNumber: flightNum,
              fromAirport: _fromAirport!.iata,
              toAirport: _toAirport!.iata,
              departureDateTime: _departureDateTime!,
              returnDateTime: _returnDateTime!,
            );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      widget.onCompleted?.call();
    } else {
      final err = ref.read(flightControllerProvider).error;
      setState(() {
        _errorMessage = err ?? 'Failed to save flight ticket. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simulated Scanner Reticle Area
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Scanner reticle frame
                Container(
                  width: 240,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.accent.withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner_rounded,
                          color: colors.accent,
                          size: 36,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Align Boarding Pass / Barcode',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // OCR / Barcode quick actions
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: colors.accent,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        icon: const Icon(Icons.paste_rounded, size: 16),
                        label: const Text('Paste OCR / Barcode'),
                        onPressed: () {
                          setState(() {
                            _showOcrInput = !_showOcrInput;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_showOcrInput) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Paste barcode string (M1...) or OCR text:',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _manualOcrController,
                    maxLines: 3,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'M1DOE/JOHN EN1234567SINNRTGA 0881 290Y...',
                      hintStyle: TextStyle(color: colors.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _showOcrInput = false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: () {
                          final text = _manualOcrController.text.trim();
                          if (text.startsWith('M')) {
                            _handleRawBarcode(text);
                          } else {
                            _handleOcrText(text);
                          }
                        },
                        child: const Text('Extract'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Form fields
          ModernTextField(
            label: 'FLIGHT NUMBER',
            hint: 'e.g. SQ 321 or GA881',
            controller: _flightNumberController,
            prefixIcon: Icons.airplanemode_active_rounded,
          ),
          const SizedBox(height: AppSpacing.md),

          // Airport picker fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FROM AIRPORT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickAirport(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flight_takeoff_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fromAirport != null
                                    ? '${_fromAirport!.iata} '
                                        '(${_fromAirport!.name})'
                                    : 'Select origin',
                                style: TextStyle(
                                  color: _fromAirport != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TO AIRPORT',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickAirport(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.flight_land_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _toAirport != null
                                    ? '${_toAirport!.iata} '
                                        '(${_toAirport!.name})'
                                    : 'Select destination',
                                style: TextStyle(
                                  color: _toAirport != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Date Time picker fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEPARTURE TIME',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickDateTime(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _departureDateTime != null
                                    ? '${_departureDateTime!.month}/${_departureDateTime!.day} ${_departureDateTime!.hour.toString().padLeft(2, '0')}:${_departureDateTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Pick departure',
                                style: TextStyle(
                                  color: _departureDateTime != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RETURN TIME',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _pickDateTime(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              color: colors.accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _returnDateTime != null
                                    ? '${_returnDateTime!.month}/${_returnDateTime!.day} ${_returnDateTime!.hour.toString().padLeft(2, '0')}:${_returnDateTime!.minute.toString().padLeft(2, '0')}'
                                    : 'Pick return',
                                style: TextStyle(
                                  color: _returnDateTime != null
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: TextStyle(
                color: colors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // Submit button
          AppButton(
            label: widget.completeButtonText,
            isLoading: _isSubmitting,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
