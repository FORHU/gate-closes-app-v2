import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/profile/data/models/profile_model.dart';

/// Talks to the remote API. Knows nothing about state or UI.
abstract class ProfileRemoteDataSource {
  Future<ProfileModel> getProfile();
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  ProfileRemoteDataSourceImpl(this._api);

  final ApiService _api;

  @override
  Future<ProfileModel> getProfile() async {
    final data = await _api.get(ApiEndpoints.me);
    return ProfileModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
