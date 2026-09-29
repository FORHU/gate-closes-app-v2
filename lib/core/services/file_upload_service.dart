import 'dart:io';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/errors/exceptions.dart';
import 'package:gate_closes/core/errors/failure.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/auth/presentation/controllers/auth_controller.dart';

/// Result of `POST /s3/upload` — see `s3.service.ts`'s `uploadFile`, which
/// returns `{url, key}`.
class UploadedFile extends Equatable {
  const UploadedFile({required this.url, required this.key});

  final String url;
  final String key;

  @override
  List<Object?> get props => [url, key];
}

/// Shared by Terminal Echo's composer and Messaging's voice messages — both
/// upload an audio file before creating the echo/message that references it.
/// Audio only, 10MB max, one of mp3/wav/m4a/aac/ogg/webm (enforced
/// server-side in `s3.service.ts`).
abstract class FileUploadService {
  Future<Either<Failure, UploadedFile>> uploadAudio(File file);
}

class FileUploadServiceImpl implements FileUploadService {
  const FileUploadServiceImpl(this._api);

  final ApiService _api;

  @override
  Future<Either<Failure, UploadedFile>> uploadAudio(File file) async {
    try {
      final fileName = file.uri.pathSegments.last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _api.post(ApiEndpoints.s3Upload, formData);
      final data = (response as Map).cast<String, dynamic>();

      return Right(
        UploadedFile(
          url: (data['url'] ?? '').toString(),
          key: (data['key'] ?? '').toString(),
        ),
      );
    } on AppException catch (e) {
      return Left(ServerFailure(e.message));
    } on Object catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

final fileUploadServiceProvider = Provider<FileUploadService>((ref) {
  return FileUploadServiceImpl(ref.watch(apiServiceProvider));
});
