import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/chat_history_service.dart';
import '../services/ollama_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.service, this.historyService});

  final OllamaApi service;
  final ChatHistoryApi? historyService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _accent = Color(0xFF9B8CFF);

  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  List<String> _models = [];
  String _selectedModel = 'llama3.2';
  String? _connectionError;
  String? _historyError;
  bool _isLoadingModels = true;
  bool _isLoadingHistory = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadModels();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    if (widget.historyService case final ChatHistoryService service) {
      service.dispose();
    }
    if (widget.service case final OllamaService service) {
      service.dispose();
    }
    super.dispose();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoadingModels = true;
      _connectionError = null;
    });
    try {
      final models = await widget.service.getModels();
      if (!mounted) return;
      setState(() {
        _models = models;
        if (models.isNotEmpty && !models.contains(_selectedModel)) {
          _selectedModel = models.first;
        }
        _isLoadingModels = false;
        _connectionError = models.isEmpty
            ? 'Ollama’da model bulunamadı. Önce bir model indirin.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingModels = false;
        _connectionError = _friendlyError(error);
      });
    }
  }

  Future<void> _loadHistory() async {
    final historyService = widget.historyService;
    if (historyService == null) return;
    setState(() => _isLoadingHistory = true);
    try {
      final messages = await historyService.load();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(messages);
        _historyError = null;
        _isLoadingHistory = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = _historyErrorMessage(error);
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _saveHistory() async {
    final historyService = widget.historyService;
    if (historyService == null) return;
    try {
      await historyService.save(List<ChatMessage>.unmodifiable(_messages));
      if (mounted) setState(() => _historyError = null);
    } catch (error) {
      if (mounted) setState(() => _historyError = _historyErrorMessage(error));
    }
  }

  Future<void> _sendMessage([String? suggestedPrompt]) async {
    final prompt = (suggestedPrompt ?? _inputController.text).trim();
    if (prompt.isEmpty || _isGenerating) return;

    final history = List<ChatMessage>.of(_messages)
      ..add(ChatMessage(role: MessageRole.user, content: prompt));
    _inputController.clear();
    _inputFocus.unfocus();
    setState(() {
      _connectionError = null;
      _isGenerating = true;
      _messages
        ..add(ChatMessage(role: MessageRole.user, content: prompt))
        ..add(const ChatMessage(role: MessageRole.assistant));
    });
    _scrollToBottom();
    await _saveHistory();

    try {
      await for (final delta in widget.service.chat(
        model: _selectedModel,
        messages: history,
      )) {
        if (!mounted) return;
        final current = _messages.last;
        setState(() {
          _messages[_messages.length - 1] = current.copyWith(
            content: '${current.content}${delta.content}',
            thinking: '${current.thinking}${delta.thinking}',
          );
        });
        _scrollToBottom();
      }
      await _saveHistory();
    } catch (error) {
      if (!mounted) return;
      final current = _messages.last;
      if (current.content.isEmpty && current.thinking.isEmpty) {
        setState(() => _messages.removeLast());
      }
      setState(() => _connectionError = _friendlyError(error));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        await _saveHistory();
        _scrollToBottom();
      }
    }
  }

  String _historyErrorMessage(Object error) =>
      'Sohbet geçmişi sunucusuna ulaşılamadı. (${error is ChatHistoryException ? error.message : error})';

  String _friendlyError(Object error) {
    final detail = error is OllamaException
        ? error.message
        : error is FormatException
        ? error.message
        : error.toString();
    return 'Ollama’ya bağlanılamadı. Sunucunun açık ve erişilebilir '
        'olduğunu kontrol edin. ($detail)';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _editModelName() async {
    final controller = TextEditingController(text: _selectedModel);
    final model = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Model adı'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'örn. qwen3:8b',
            labelText: 'Ollama model etiketi',
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Kullan'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (model != null && model.isNotEmpty && mounted) {
      setState(() => _selectedModel = model);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1016),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.auto_awesome, color: _accent, size: 21),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ollama Chat',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Yerel yapay zeka',
                  style: TextStyle(fontSize: 11, color: Color(0xFF979BAA)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _buildModelSelector(),
          IconButton(
            tooltip: 'Modelleri yenile',
            onPressed: _isLoadingModels ? null : _loadModels,
            icon: _isLoadingModels
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 21),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          if (_historyError != null)
            MaterialBanner(
              content: Text(_historyError!),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(
                  onPressed: _loadHistory,
                  child: const Text('Yenile'),
                ),
              ],
            ),
          if (_isLoadingHistory) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) => _MessageBubble(
                      message: _messages[index],
                      isStreaming:
                          _isGenerating && index == _messages.length - 1,
                    ),
                  ),
          ),
          if (_isGenerating) const _ThinkingIndicator(),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildModelSelector() {
    if (_models.isEmpty) {
      return TextButton(
        onPressed: _editModelName,
        child: Text(
          _selectedModel,
          style: const TextStyle(color: _accent, fontSize: 12),
        ),
      );
    }
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _models.contains(_selectedModel) ? _selectedModel : null,
        hint: Text(_selectedModel, style: const TextStyle(fontSize: 12)),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        borderRadius: BorderRadius.circular(14),
        dropdownColor: const Color(0xFF20232D),
        items: _models
            .map(
              (model) => DropdownMenuItem(
                value: model,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(model, overflow: TextOverflow.ellipsis),
                ),
              ),
            )
            .toList(),
        onChanged: (model) {
          if (model != null) setState(() => _selectedModel = model);
        },
      ),
    );
  }

  Widget _buildConnectionStatus() {
    final connected =
        !_isLoadingModels && _connectionError == null && _models.isNotEmpty;
    final color = connected ? const Color(0xFF63D6A1) : const Color(0xFFFFB86B);
    final label = _isLoadingModels
        ? 'Ollama’ya bağlanılıyor…'
        : connected
        ? 'Ollama bağlı'
        : _connectionError ?? 'Model adı elle seçildi';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      color: const Color(0xFF151821),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _accent.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.auto_awesome, color: _accent, size: 34),
            ),
            const SizedBox(height: 22),
            const Text(
              'Bugün ne keşfedelim?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 9),
            const Text(
              'Yerel modelinle gizli ve hızlı bir sohbete başla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF979BAA), fontSize: 14),
            ),
            const SizedBox(height: 26),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 9,
              runSpacing: 9,
              children: [
                _SuggestionChip(
                  label: 'Bir fikri açıkla',
                  icon: Icons.lightbulb_outline,
                  onTap: () => _sendMessage('Bana ilginç bir fikir açıkla.'),
                ),
                _SuggestionChip(
                  label: 'Kod yazmama yardım et',
                  icon: Icons.code_rounded,
                  onTap: () => _sendMessage('Flutter’da bir sayaç örneği yaz.'),
                ),
                _SuggestionChip(
                  label: 'Yaratıcı bir şey yaz',
                  icon: Icons.edit_note_rounded,
                  onTap: () => _sendMessage('Kısa, umut veren bir hikâye yaz.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D27),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFF2A2E3A)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  enabled: !_isGenerating,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Mesajını yaz…',
                    hintStyle: TextStyle(color: Color(0xFF858A9A)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.fromLTRB(18, 15, 8, 15),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(7),
                child: Material(
                  color: _isGenerating ? const Color(0xFF393344) : _accent,
                  borderRadius: BorderRadius.circular(17),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(17),
                    onTap: _isGenerating ? null : _sendMessage,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        _isGenerating
                            ? Icons.hourglass_top_rounded
                            : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.isStreaming = false});

  final ChatMessage message;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isUser)
                const Padding(
                  padding: EdgeInsets.only(left: 3, bottom: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: _ChatScreenState._accent,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Ollama',
                        style: TextStyle(
                          color: Color(0xFFA9ADBB),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isUser && message.thinking.isNotEmpty)
                _ThinkingPanel(
                  thinking: message.thinking,
                  isStreaming: isStreaming,
                ),
              if (message.content.isNotEmpty || isUser)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? const Color(0xFF7968E8)
                        : const Color(0xFF1B1E28),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(19),
                      topRight: const Radius.circular(19),
                      bottomLeft: Radius.circular(isUser ? 19 : 5),
                      bottomRight: Radius.circular(isUser ? 5 : 19),
                    ),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFF292D39)),
                  ),
                  child: SelectableText(
                    message.content.isEmpty && isUser ? '' : message.content,
                    style: const TextStyle(fontSize: 14, height: 1.55),
                  ),
                ),
              if (!isUser && isStreaming && message.content.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 5),
                  child: SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThinkingPanel extends StatelessWidget {
  const _ThinkingPanel({required this.thinking, required this.isStreaming});

  final String thinking;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171922),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF303342)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isStreaming,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
          dense: true,
          leading: const Icon(Icons.psychology_alt_outlined, size: 18),
          title: Text(
            isStreaming ? 'Düşünüyor…' : 'Düşünme süreci',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                thinking,
                style: const TextStyle(
                  color: Color(0xFFB0B3C0),
                  fontSize: 12,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Row(
        children: [
          Icon(Icons.bolt_rounded, color: Color(0xFF9B8CFF), size: 15),
          SizedBox(width: 6),
          Text(
            'Model yanıt hazırlıyor',
            style: TextStyle(color: Color(0xFF979BAA), fontSize: 11),
          ),
          SizedBox(width: 9),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: const Color(0xFFB2A8FF)),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFF191C25),
      side: const BorderSide(color: Color(0xFF2B2E3A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
