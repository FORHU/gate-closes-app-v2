import 'package:flutter_test/flutter_test.dart';
import 'package:gate_closes/core/constants/api_endpoints.dart';
import 'package:gate_closes/core/services/api_service.dart';
import 'package:gate_closes/features/connections/data/repositories/messages_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

void main() {
  test('sends a voice message duration as milliseconds, once', () async {
    final api = MockApiService();
    when(() => api.post(any(), any())).thenAnswer(
      (_) async => {
        'data': {'id': 'm1', 'conversationId': 'c1', 'senderId': 'u1'},
      },
    );

    await MessagesRepositoryImpl(api).sendVoiceMessage(
      conversationId: 'c1',
      fileUrl: 'http://localhost:9200/b/a.m4a',
      audioDuration: 3.4,
      waveformData: const [0.5],
    );

    final body = verify(
      () => api.post(ApiEndpoints.conversationMessages('c1'), captureAny()),
    ).captured.single as Map<String, dynamic>;
    // 3.4 s → 3400 ms (the page used to convert as well: 3,400,000).
    expect(body['audioDuration'], 3400);
  });
}
