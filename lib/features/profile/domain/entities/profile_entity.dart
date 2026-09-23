import 'package:equatable/equatable.dart';

/// Extended profile info beyond the auth session's user record — fetched
/// separately from `/users/me` since not every backend returns bio/join-date
/// on login.
class ProfileEntity extends Equatable {
  const ProfileEntity({
    required this.id,
    required this.name,
    required this.email,
    this.bio,
    this.joinedAt,
  });

  final String id;
  final String name;
  final String email;
  final String? bio;
  final DateTime? joinedAt;

  @override
  List<Object?> get props => [id, name, email, bio, joinedAt];
}
