import 'dart:convert';
import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

Future<void> main() async {
  final mongoUri = Platform.environment['MONGODB_URI'];
  if (mongoUri == null || mongoUri.isEmpty) {
    stderr.writeln('MONGODB_URI ortam değişkeni tanımlanmalıdır.');
    exitCode = 64;
    return;
  }

  final database = await Db.create(mongoUri);
  await database.open();
  final histories = database.collection('chat_histories');
  final router = Router()
    ..get('/health', (request) => Response.ok('ok'))
    ..get('/history/<deviceId>', (request, deviceId) async {
      final history = await histories.findOne(where.eq('_id', deviceId));
      return _jsonResponse({
        'messages': history?['messages'] ?? <Map<String, dynamic>>[],
      });
    })
    ..put('/history/<deviceId>', (request, deviceId) async {
      final body = await request.readAsString();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> || decoded['messages'] is! List) {
        return _jsonResponse({'error': 'messages dizisi gereklidir.'}, 400);
      }

      final messages = decoded['messages'] as List;
      if (messages.length > 500 ||
          messages.any((message) => !_isValidMessage(message))) {
        return _jsonResponse({'error': 'Sohbet mesajları geçersiz.'}, 400);
      }

      await histories.updateOne(
        where.eq('_id', deviceId),
        modify.set('messages', messages),
        upsert: true,
      );
      return Response(204);
    });

  final handler = const Pipeline()
      .addMiddleware(_corsMiddleware())
      .addMiddleware(logRequests())
      .addHandler(router.call);
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln(
    'Sohbet geçmişi API hazır: http://${server.address.host}:${server.port}',
  );

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    await database.close();
    exit(0);
  });
}

bool _isValidMessage(Object? value) {
  if (value is! Map) return false;
  final role = value['role'];
  return (role == 'user' || role == 'assistant') &&
      value['content'] is String &&
      (value['thinking'] == null || value['thinking'] is String);
}

Response _jsonResponse(Object body, [int statusCode = 200]) => Response(
  statusCode,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Middleware _corsMiddleware() =>
    (innerHandler) => (request) async {
      const headers = {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, PUT, OPTIONS',
        'access-control-allow-headers': 'Origin, Content-Type',
      };
      if (request.method == 'OPTIONS') {
        return Response(204, headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ...headers});
    };
