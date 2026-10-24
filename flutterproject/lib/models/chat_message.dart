enum MessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    this.content = '',
    this.thinking = '',
  });

  final MessageRole role;
  final String content;
  final String thinking;

  ChatMessage copyWith({String? content, String? thinking}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      thinking: thinking ?? this.thinking,
    );
  }
}
