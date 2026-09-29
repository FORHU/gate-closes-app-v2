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
    final payload = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map)
            ? (json['data'] as Map).cast<String, dynamic>()
            : json;

    return ProfileModel(
      id: (payload['id'] ?? '').toString(),
      name: (payload['name'] ?? payload['username'] ?? '').toString(),
      email: (payload['email'] ?? '').toString(),
      bio: payload['bio'] as String?,
      joinedAt: payload['joinedAt'] != null
          ? DateTime.tryParse(payload['joinedAt'].toString())
          : null,
    );
  }
}
