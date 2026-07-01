import 'package:flutter/material.dart';

import 'inventory_agent.dart';

const _kAgentRed = Color(0xFFA80000);

Future<void> showInventoryAgentChat(
  BuildContext context,
  InventoryAgent agent, {
  Future<String?> Function()? onVoiceInput,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => InventoryChatDialog(
      agent: agent,
      onVoiceInput: onVoiceInput,
    ),
  );
}

class InventoryChatDialog extends StatelessWidget {
  final InventoryAgent agent;
  final Future<String?> Function()? onVoiceInput;

  const InventoryChatDialog({
    super.key,
    required this.agent,
    this.onVoiceInput,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: size.width > 640 ? 560 : size.width,
        height: size.height * 0.78,
        child: InventoryChatPanel(
          agent: agent,
          showCloseButton: true,
          onVoiceInput: onVoiceInput,
        ),
      ),
    );
  }
}

class InventoryAgentScreen extends StatefulWidget {
  final InventoryAgent? agent;

  const InventoryAgentScreen({
    super.key,
    this.agent,
  });

  @override
  State<InventoryAgentScreen> createState() => _InventoryAgentScreenState();
}

class _InventoryAgentScreenState extends State<InventoryAgentScreen> {
  late final InventoryAgent _agent;
  late final bool _ownsAgent;

  @override
  void initState() {
    super.initState();
    _ownsAgent = widget.agent == null;
    _agent = widget.agent ?? InventoryAgent.createDefault();
  }

  @override
  void dispose() {
    if (_ownsAgent) {
      _agent.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ИИ-агент'),
        backgroundColor: _kAgentRed,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: InventoryChatPanel(agent: _agent),
      ),
    );
  }
}

class InventoryChatPanel extends StatefulWidget {
  final InventoryAgent agent;
  final bool showCloseButton;
  final Future<String?> Function()? onVoiceInput;

  const InventoryChatPanel({
    super.key,
    required this.agent,
    this.showCloseButton = false,
    this.onVoiceInput,
  });

  @override
  State<InventoryChatPanel> createState() => _InventoryChatPanelState();
}

class _InventoryChatPanelState extends State<InventoryChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage.assistant('Готов помочь с инвентарем.'),
  ];

  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendText([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage.user(text));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    final reply = await widget.agent.sendMessage(text);
    if (!mounted) return;

    setState(() {
      _messages.add(_ChatMessage.assistant(reply.text, isError: reply.isError));
      _isSending = false;
    });
    _scrollToBottom();
  }

  Future<void> _startVoiceInput() async {
    final handler = widget.onVoiceInput;
    if (handler == null || _isSending) return;

    final text = await handler();
    if (text == null || text.trim().isEmpty) return;
    await _sendText(text);
  }

  void _resetConversation() {
    widget.agent.resetConversation();
    setState(() {
      _messages
        ..clear()
        ..add(const _ChatMessage.assistant('Диалог очищен.'));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(child: _buildHistory()),
        const Divider(height: 1),
        _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_outlined, color: _kAgentRed),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'ИИ-агент',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Очистить диалог',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: _isSending ? null : _resetConversation,
          ),
          if (widget.showCloseButton)
            IconButton(
              tooltip: 'Закрыть',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      itemCount: _messages.length + (_isSending ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isSending && index == _messages.length) {
          return const _TypingBubble();
        }
        return _MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Голосовой ввод',
              icon: const Icon(Icons.mic_none_rounded),
              onPressed: widget.onVoiceInput == null ? null : _startVoiceInput,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                enabled: !_isSending,
                onSubmitted: (_) => _sendText(),
                decoration: InputDecoration(
                  hintText: 'Сообщение',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Отправить',
              style: IconButton.styleFrom(backgroundColor: _kAgentRed),
              icon: const Icon(Icons.send_rounded),
              onPressed: _isSending ? null : _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final background = isUser
        ? _kAgentRed
        : message.isError
            ? const Color(0xFFFFEBEE)
            : Colors.grey.shade100;
    final foreground = isUser
        ? Colors.white
        : message.isError
            ? const Color(0xFF8B0000)
            : Colors.black87;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: message.isError
                ? Border.all(color: const Color(0xFFFFCDD2))
                : null,
          ),
          child: Text(
            message.text,
            style: TextStyle(color: foreground, fontSize: 15, height: 1.25),
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 54,
        height: 34,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage.user(this.text)
      : isUser = true,
        isError = false;

  const _ChatMessage.assistant(
    this.text, {
    this.isError = false,
  }) : isUser = false;
}
