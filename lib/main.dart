import 'package:gate_closes/bootstrap.dart';
import 'package:gate_closes/core/config/app_config.dart';

/// Default entry point for a bare `flutter run` (no `-t`).
/// Loads `.env.dev` at runtime via flutter_dotenv.
///
/// For explicit, define-free targets use `lib/main_dev.dart` or
/// `lib/main_prod.dart`.
Future<void> main() => bootstrap(
      const AppConfig.dev(), // fallback, overridden after dotenv loads
      dotEnvFile: '.env.dev',
    );
