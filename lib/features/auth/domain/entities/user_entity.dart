import 'package:equatable/equatable.dart';

/// Pure domain object — no JSON, no framework types. Equatable gives value
/// equality so two users with the same fields compare equal.
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    this.gender,
    this.picture,
    this.signupCompleted = true,
    this.isCompleteProfile = true,
    this.permissions = const [],
  });

  final String id;
  final String email;
  final String name;
  final String? gender;
  final String? picture;
  final bool signupCompleted;
  final bool isCompleteProfile;

  /// What the user's role allows (from `GET /auth/me`), e.g.
  /// `airports:simulate`. Empty until `/auth/me` has been read.
  final List<String> permissions;

  @override
  List<Object?> get props => [
        id,
        email,
        name,
        gender,
        picture,
        signupCompleted,
        isCompleteProfile,
        permissions,
      ];
}
