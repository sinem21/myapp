import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_message.dart';

abstract interface class ChatHistoryApi {
  Future<List<ChatMessage>> load();

  Future<void> save(List<ChatMessage> messages);
}

class ChatHistoryService implements ChatHistoryApi {
  ChatHistoryService({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'HISTORY_API_URL',
      defaultValue: 'http://10.0.2.2:8080',
    ),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  String? _deviceId;

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$normalized$path');
  }

  Future<String> _getDeviceId() async {
    if (_deviceId case final id?) return id;
    final preferences = await SharedPreferences.getInstance();
    _deviceId = preferences.getString('chat_history_device_id');
    if (_deviceId == null) {
      _deviceId = DateTime.now().microsecondsSinceEpoch.toString();
      await preferences.setString('chat_history_device_id', _deviceId!);
    }
    return _deviceId!;
  }

  @override
  Future<List<ChatMessage>> load() async {
    final response = await _client
        .get(_uri('/history/${await _getDeviceId()}'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatHistoryException(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['messages'] is! List) {
      throw const FormatException('Sohbet geçmişi yanıtı geçersiz.');
    }
    return (decoded['messages'] as List)
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Sohbet mesajı geçersiz.');
          }
          final role = item['role'];
          final content = item['content'];
          final thinking = item['thinking'];
          if ((role != 'user' && role != 'assistant') || content is! String) {
            throw const FormatException('Sohbet mesajı geçersiz.');
          }
          return ChatMessage(
            role: role == 'user' ? MessageRole.user : MessageRole.assistant,
            content: content,
            thinking: thinking is String ? thinking : '',
          );
        })
        .where(
          (message) =>
              message.role == MessageRole.user ||
              message.content.isNotEmpty ||
              message.thinking.isNotEmpty,
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(List<ChatMessage> messages) async {
    final response = await _client
        .put(
          _uri('/history/${await _getDeviceId()}'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'messages': messages
                .where(
                  (message) =>
                      message.role == MessageRole.user ||
                      message.content.isNotEmpty ||
                      message.thinking.isNotEmpty,
                )
                .map(
                  (message) => {
                    'role': message.role == MessageRole.user
                        ? 'user'
                        : 'assistant',
                    'content': message.content,
                    'thinking': message.thinking,
                  },
                )
                .toList(growable: false),
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatHistoryException(_errorMessage(response));
    }
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // Fall back to the HTTP status when the API response is not JSON.
    }
    return 'Sohbet geçmişi API isteği başarısız oldu (HTTP ${response.statusCode}).';
  }

  void dispose() => _client.close();
}

class ChatHistoryException implements Exception {
  const ChatHistoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
