import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_template/core/errors/failure.dart';
import 'package:flutter_template/core/services/storage_service.dart';
import 'package:flutter_template/features/profile/data/repositories/profile_repository.dart';
import 'package:flutter_template/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter_template/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flutter_template/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter_template/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  testWidgets(
    'ProfilePage renders the fetched profile with no layout errors',
    (tester) async {
      final mockRepository = MockProfileRepository();
      final mockStorage = MockStorageService();
      when(mockStorage.readUserModel).thenReturn(null);
      when(mockRepository.getProfile).thenAnswer(
        (_) async => const Right(
          ProfileEntity(
            id: '1',
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            bio: 'Building great things with Flutter.',
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            profileRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(
        find.text('Building great things with Flutter.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ProfilePage falls back to session data with a retry option on failure',
    (tester) async {
      final mockRepository = MockProfileRepository();
      final mockStorage = MockStorageService();
      when(mockStorage.readUserModel).thenReturn(null);
      when(
        mockRepository.getProfile,
      ).thenAnswer((_) async => const Left(NetworkFailure()));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            profileRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfilePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
