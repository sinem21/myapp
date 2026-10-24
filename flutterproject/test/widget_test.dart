import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutterproject/models/chat_message.dart';
import 'package:flutterproject/screens/chat_screen.dart';
import 'package:flutterproject/services/ollama_service.dart';

void main() {
  testWidgets('shows the local chat welcome screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(service: _FakeOllamaApi())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bugün ne keşfedelim?'), findsOneWidget);
    expect(find.text('Ollama Chat'), findsOneWidget);
    expect(find.text('llama3.2'), findsOneWidget);
  });

  testWidgets('sends a message and renders thinking and answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: ChatScreen(service: _FakeOllamaApi())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Merhaba');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text('Merhaba, nasıl yardımcı olabilirim?'), findsOneWidget);
    await tester.tap(find.text('Düşünme süreci'));
    await tester.pumpAndSettle();
    expect(find.text('Önce soruyu değerlendiriyorum.'), findsOneWidget);
  });
}

class _FakeOllamaApi implements OllamaApi {
  @override
  Future<List<String>> getModels() async => ['llama3.2'];

  @override
  Stream<ChatDelta> chat({
    required String model,
    required List<ChatMessage> messages,
  }) async* {
    expect(model, 'llama3.2');
    expect(messages.last.content, 'Merhaba');
    yield const ChatDelta(thinking: 'Önce soruyu değerlendiriyorum.');
    yield const ChatDelta(content: 'Merhaba, nasıl yardımcı olabilirim?');
  }
}
