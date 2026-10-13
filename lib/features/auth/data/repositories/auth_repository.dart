import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/cookie_service.dart';
import 'package:gate_closes/core/services/storage_service.dart';
import 'package:gate_closes/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:gate_closes/features/auth/domain/entities/registration_step.dart';
import 'package:gate_closes/features/auth/domain/entities/user_entity.dart';

/// Repository contract (the abstraction the domain layer depends on).
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login(String email, String password);

  /// Signs in with a Google ID token and loads the full user (`/auth/me`).
  /// The user is cached as signed in only once the profile is complete; a
  /// new Google account finishes signup with [setUsernameGender] first.
  Future<Either<Failure, UserEntity>> loginWithGoogle(String idToken);

  // --- Signup wizard (keyed by email) ---
  Future<Either<Failure, void>> registerEmail(String email);

  /// Signs in with the code and keeps the session for the next steps.
  Future<Either<Failure, RegistrationStep>> verifyEmail(
    String email,
    String code,
  );
  Future<Either<Failure, void>> resendCode(String email);
  Future<Either<Failure, RegistrationStep>> setPassword(
    String password,
    String confirmPassword,
  );
  Future<Either<Failure, RegistrationStep>> setUsernameGender(
    String username,
    String gender,
  );

  // --- Forgot-password wizard (keyed by email) ---
  Future<Either<Failure, void>> forgotPassword(String email);
  Future<Either<Failure, void>> resendResetCode(String email);
  Future<Either<Failure, void>> verifyResetCode(String email, String code);
  Future<Either<Failure, void>> resetPassword(
    String email,
    String code,
    String password,
  );

  Future<Either<Failure, void>> logout();
  Future<Either<Failure, UserEntity>> refreshAuth();
  Future<Either<Failure, UserEntity>> editProfile({
    String? username,
    String? gender,
  });
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  });
}

/// Coordinates the remote data source and local token storage. Catches the
/// data layer's typed exceptions and maps them to typed [Failure] values.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(
    this._remote,
    this._storage, {
    CookieService? cookieService,
  }) : _cookieService = cookieService;

  final AuthRemoteDataSource _remote;
  final StorageService _storage;
  final CookieService? _cookieService;

  @override
  Future<Either<Failure, UserEntity>> login(String email, String password) =>
      _run(() async {
        final user = await _remote.login(email, password);
        await _storage.saveToken(user.token);
        // Save full user model to local cache for instant offline startup.
        await _storage.saveUserModel(user);
        return user;
      });

  @override
  Future<Either<Failure, UserEntity>> loginWithGoogle(String idToken) =>
      _run(() async {
        final session = await _remote.signInWithGoogle(idToken);
        await _storage.saveToken(session.token);
        final user = await _remote.checkAuth();
        if (user.isCompleteProfile) await _storage.saveUserModel(user);
        return user;
      });

  @override
  Future<Either<Failure, void>> registerEmail(String email) =>
      _run(() => _remote.sendSignupCode(email));

  @override
  Future<Either<Failure, RegistrationStep>> verifyEmail(
    String email,
    String code,
  ) =>
      _run(() async {
        final result = await _remote.verifyEmail(email, code);
        await _storage.saveToken(result.token);
        return RegistrationStep(
          message: '',
          signupStep: result.signupStep,
        );
      });

  @override
  Future<Either<Failure, void>> resendCode(String email) =>
      _run(() => _remote.sendSignupCode(email));

  @override
  Future<Either<Failure, RegistrationStep>> setPassword(
    String password,
    String confirmPassword,
  ) =>
      _run(() => _remote.setPassword(password, confirmPassword));

  @override
  Future<Either<Failure, RegistrationStep>> setUsernameGender(
    String username,
    String gender,
  ) =>
      _run(() => _remote.setUsernameGender(username, gender));

  @override
  Future<Either<Failure, void>> forgotPassword(String email) =>
      _run(() => _remote.sendResetCode(email));

  @override
  Future<Either<Failure, void>> resendResetCode(String email) =>
      _run(() => _remote.sendResetCode(email));

  @override
  Future<Either<Failure, void>> verifyResetCode(String email, String code) =>
      _run(() => _remote.checkResetCode(email, code));

  @override
  Future<Either<Failure, void>> resetPassword(
    String email,
    String code,
    String password,
  ) =>
      _run(() => _remote.resetPassword(email, code, password));

  @override
  Future<Either<Failure, void>> logout() async {
    // Best-effort server-side sign-out, then always clear the local session.
    // Refusing to sign out while offline would trap the user in the app; once
    // the token is deleted from the device, the orphaned server session can't
    // be used from here and simply expires.
    try {
      await _remote.logout();
    } on AppException catch (_) {
      // Offline, server error, or session already ended — sign out anyway.
    }

    try {
      await _storage.clearSession();
      await _cookieService?.clearCookies();
      return const Right(null);
    } on Object catch (e) {
      return Left(CacheFailure('Failed to clear local session: $e'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> refreshAuth() async {
    try {
      final token = await _storage.readToken();
      if (token == null || token.isEmpty) {
        return const Left(UnauthorizedFailure('No token found'));
      }
      final user = await _remote.checkAuth();
      // Update local cache with fresh background fetch.
      await _storage.saveUserModel(user);
      return Right(user);
    } on UnauthorizedException catch (e) {
      await _storage.clearSession(); // Clear stale tokens.
      await _cookieService?.clearCookies();
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// Shared try/catch: every call maps the data layer's errors the same way.
  Future<Either<Failure, T>> _run<T>(Future<T> Function() call) async {
    try {
      return Right(await call());
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> editProfile({
    String? username,
    String? gender,
  }) async {
    try {
      final updated = await _remote.editProfile(
        username: username,
        gender: gender,
      );
      await _storage.saveUserModel(updated);
      return Right(updated);
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) =>
      _run(
        () => _remote.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        ),
      );
}
