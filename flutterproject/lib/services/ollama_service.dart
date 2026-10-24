import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

abstract interface class OllamaApi {
  Future<List<String>> getModels();

  Stream<ChatDelta> chat({
    required String model,
    required List<ChatMessage> messages,
  });
}

class ChatDelta {
  const ChatDelta({this.thinking = '', this.content = ''});

  final String thinking;
  final String content;
}

class OllamaService implements OllamaApi {
  OllamaService({http.Client? client, this.baseUrl = 'http://10.0.2.2:11434'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Uri get _baseUri {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse(normalized);
  }

  @override
  Future<List<String>> getModels() async {
    final response = await _client
        .get(_baseUri.resolve('/api/tags'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OllamaException(
        'Model listesi alınamadı (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['models'] is! List) {
      throw const FormatException('Ollama model yanıtı geçersiz.');
    }

    return (decoded['models'] as List)
        .whereType<Map<String, dynamic>>()
        .map((model) => model['name'])
        .whereType<String>()
        .toList(growable: false);
  }

  @override
  Stream<ChatDelta> chat({
    required String model,
    required List<ChatMessage> messages,
  }) async* {
    final request = http.Request('POST', _baseUri.resolve('/api/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': messages
            .map(
              (message) => {
                'role': message.role == MessageRole.user ? 'user' : 'assistant',
                'content': message.content,
              },
            )
            .toList(growable: false),
      });

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw OllamaException(_errorMessage(response.statusCode, body));
    }

    final parser = _ThinkingTagParser();
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;

      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Ollama akış yanıtı geçersiz.');
      }
      if (decoded['error'] case final String error) {
        throw OllamaException(error);
      }

      final message = decoded['message'];
      if (message is Map<String, dynamic>) {
        final thinking = message['thinking'];
        if (thinking is String && thinking.isNotEmpty) {
          yield ChatDelta(thinking: thinking);
        }

        final content = message['content'];
        if (content is String && content.isNotEmpty) {
          final parsed = parser.add(content);
          if (parsed.thinking.isNotEmpty || parsed.content.isNotEmpty) {
            yield parsed;
          }
        }
      }
    }

    final remaining = parser.finish();
    if (remaining.thinking.isNotEmpty || remaining.content.isNotEmpty) {
      yield remaining;
    }
  }

  String _errorMessage(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Use the status code when the server does not return a JSON error.
    }
    return 'Ollama isteği başarısız oldu (HTTP $statusCode).';
  }

  void dispose() => _client.close();
}

class OllamaException implements Exception {
  const OllamaException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _ThinkingTagParser {
  static const _openTag = '<think>';
  static const _closeTag = '</think>';

  bool _insideThinking = false;
  String _pending = '';

  ChatDelta add(String chunk) {
    var input = _pending + chunk;
    _pending = '';
    final thinking = StringBuffer();
    final content = StringBuffer();

    while (input.isNotEmpty) {
      final tag = _insideThinking ? _closeTag : _openTag;
      final tagIndex = input.toLowerCase().indexOf(tag);
      if (tagIndex >= 0) {
        (_insideThinking ? thinking : content).write(
          input.substring(0, tagIndex),
        );
        input = input.substring(tagIndex + tag.length);
        _insideThinking = !_insideThinking;
        continue;
      }

      var pendingLength = 0;
      final lowerInput = input.toLowerCase();
      for (
        var length = 1;
        length < tag.length && length <= input.length;
        length++
      ) {
        if (lowerInput.endsWith(tag.substring(0, length))) {
          pendingLength = length;
        }
      }
      final safeLength = input.length - pendingLength;
      (_insideThinking ? thinking : content).write(
        input.substring(0, safeLength),
      );
      _pending = input.substring(safeLength);
      break;
    }

    return ChatDelta(
      thinking: thinking.toString(),
      content: content.toString(),
    );
  }

  ChatDelta finish() {
    final result = _insideThinking
        ? ChatDelta(thinking: _pending)
        : ChatDelta(content: _pending);
    _pending = '';
    return result;
  }
}
