import 'package:logger/logger.dart';

/// A global instance of Logger.
/// Replace all generic `print()` and `debugPrint()` statements
/// with this structured logger.
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    lineLength: 100,
  ),
);
