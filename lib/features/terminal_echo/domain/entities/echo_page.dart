import 'package:equatable/equatable.dart';
import 'package:gate_closes/features/terminal_echo/domain/entities/terminal_echo_entity.dart';

/// One page of a feed, latest first. [nextCursor] fetches the page after
/// it; null on the last page.
class EchoPage extends Equatable {
  const EchoPage({required this.echoes, this.nextCursor});

  final List<TerminalEchoEntity> echoes;
  final String? nextCursor;

  @override
  List<Object?> get props => [echoes, nextCursor];
}
