import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutterproject/models/chat_message.dart';
import 'package:flutterproject/services/chat_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads saved messages using a persistent device identifier', () async {
    String? requestedDeviceId;
    final client = MockClient((request) async {
      requestedDeviceId = request.url.pathSegments.last;
      return http.Response(
        jsonEncode({
          'messages': [
            {'role': 'user', 'content': 'Selam'},
            {'role': 'assistant', 'content': 'Merhaba', 'thinking': ''},
          ],
        }),
        200,
      );
    });
    final service = ChatHistoryService(
      client: client,
      baseUrl: 'http://localhost',
    );

    final messages = await service.load();

    expect(requestedDeviceId, isNotEmpty);
    expect(messages.map((message) => message.content), ['Selam', 'Merhaba']);
    service.dispose();
  });

  test('saves messages without empty assistant placeholders', () async {
    final client = MockClient((request) async {
      expect(request.method, 'PUT');
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['messages'], [
        {'role': 'user', 'content': 'Selam', 'thinking': ''},
      ]);
      return http.Response('', 204);
    });
    final service = ChatHistoryService(
      client: client,
      baseUrl: 'http://localhost',
    );

    await service.save(const [
      ChatMessage(role: MessageRole.user, content: 'Selam'),
      ChatMessage(role: MessageRole.assistant),
    ]);
    service.dispose();
  });
}
