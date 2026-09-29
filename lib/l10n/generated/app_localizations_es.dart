// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Gate Closes';

  @override
  String get login => 'Iniciar sesión';

  @override
  String get logout => 'Cerrar sesión';

  @override
  String get email => 'Correo electrónico';

  @override
  String get password => 'Contraseña';

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get signInToContinue => 'Inicia sesión para continuar';

  @override
  String get loginHint =>
      'Pista: cualquier correo y una contraseña de 6+ caracteres';

  @override
  String get home => 'Inicio';

  @override
  String get profile => 'Perfil';

  @override
  String get worldMap => 'World Map';

  @override
  String get connections => 'Conexiones';
}
