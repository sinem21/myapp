import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutterproject/models/chat_message.dart';
import 'package:flutterproject/services/ollama_service.dart';

void main() {
  test('loads installed model names from the tags endpoint', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/tags');
      return http.Response(
        jsonEncode({
          'models': [
            {'name': 'qwen3:8b'},
          ],
        }),
        200,
      );
    });
    final service = OllamaService(client: client);

    expect(await service.getModels(), ['qwen3:8b']);
    service.dispose();
  });

  test(
    'streams chat deltas and extracts think tags split across chunks',
    () async {
      final body = [
        jsonEncode({
          'message': {'content': 'Önce <thi'},
          'done': false,
        }),
        jsonEncode({
          'message': {'content': 'nk>akıl yürütme</think>Yanıt'},
          'done': false,
        }),
        jsonEncode({
          'message': {'thinking': ' Ek düşünce.', 'content': ' tamam.'},
          'done': true,
        }),
      ].join('\n');
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/chat');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload['stream'], isTrue);
        expect(payload['model'], 'qwen3:8b');
        expect(payload['messages'], [
          {'role': 'user', 'content': 'Selam'},
        ]);
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/x-ndjson; charset=utf-8'},
        );
      });
      final service = OllamaService(client: client);

      final deltas = await service
          .chat(
            model: 'qwen3:8b',
            messages: const [
              ChatMessage(role: MessageRole.user, content: 'Selam'),
            ],
          )
          .toList();

      expect(
        deltas.map((delta) => delta.thinking).join(),
        'akıl yürütme Ek düşünce.',
      );
      expect(deltas.map((delta) => delta.content).join(), 'Önce Yanıt tamam.');
      service.dispose();
    },
  );

  test('reports an Ollama error response', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode({'error': 'model bulunamadı'})),
        404,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final service = OllamaService(client: client);

    await expectLater(
      service.chat(model: 'missing', messages: const []).toList(),
      throwsA(
        isA<OllamaException>().having(
          (error) => error.message,
          'message',
          'model bulunamadı',
        ),
      ),
    );
    service.dispose();
  });
}
