import 'package:gate_closes/features/profile/domain/entities/profile_entity.dart';

/// Data-layer extension of [ProfileEntity] that knows how to deserialize.
class ProfileModel extends ProfileEntity {
  const ProfileModel({
    required super.id,
    required super.name,
    required super.email,
    super.bio,
    super.joinedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> map(Object? v) =>
        v is Map ? v.cast<String, dynamic>() : const {};
    final data = json['data'] is Map ? map(json['data']) : json;
    // `GET /auth/me` nests the account under `user`; the top level holds
    // `permissions`. Reading the top level gave an empty name, shown as "?".
    final payload = data['user'] is Map ? map(data['user']) : data;
    final username = payload['username']?.toString() ?? '';
    final name = payload['name']?.toString() ?? '';

    return ProfileModel(
      id: (payload['id'] ?? payload['_id'] ?? '').toString(),
      name: username.isNotEmpty ? username : name,
      email: (payload['email'] ?? '').toString(),
      bio: payload['bio'] as String?,
      joinedAt: payload['joinedAt'] != null
          ? DateTime.tryParse(payload['joinedAt'].toString())
          : null,
    );
  }
}
