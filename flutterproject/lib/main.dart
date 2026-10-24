import 'package:flutter/material.dart';

import 'screens/chat_screen.dart';
import 'services/ollama_service.dart';

void main() {
  runApp(const OllamaChatApp());
}

class OllamaChatApp extends StatelessWidget {
  const OllamaChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ollama Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B7CFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF151821),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1016),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: ChatScreen(service: OllamaService()),
    );
  }
}
