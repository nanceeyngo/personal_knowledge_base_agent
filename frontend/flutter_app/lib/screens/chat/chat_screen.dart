import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../models/collection.dart';
import '../../models/message.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/message_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.collection});
  final Collection collection;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController
              .jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    setState(() => _isSending = true);
    try {
      await ref
          .read(chatProvider(widget.collection.id).notifier)
          .sendMessage(text);
    } finally {
      if (mounted) setState(() => _isSending = false);
      _focusNode.requestFocus();
    }
  }

  void _insertNewline() {
    final ctrl = _textController;
    final sel = ctrl.selection;
    final newText = ctrl.text.replaceRange(sel.start, sel.end, '\n');
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatProvider(widget.collection.id));

    ref.listen(chatProvider(widget.collection.id), (_, next) {
      if (next.hasValue) _scrollToBottom();
    });

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () =>
            const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(e.toString(),
                  style: const TextStyle(color: Colors.redAccent)),
            ),
            data: (messages) => messages.isEmpty
                ? _EmptyChatView(collection: widget.collection)
                : ListView.builder(
              controller: _scrollController,
              padding:
              const EdgeInsets.symmetric(vertical: 16),
              itemCount: messages.length,
              itemBuilder: (_, i) =>
                  MessageBubble(message: messages[i]),
            ),
          ),
        ),
        _InputBar(
          controller: _textController,
          focusNode: _focusNode,
          isSending: _isSending,
          onSend: _send,
          onInsertNewline: _insertNewline,
          onNewChat: () => ref
              .read(chatProvider(widget.collection.id).notifier)
              .newConversation(),
        ),
      ],
    );
  }
}

// ── Input bar ──────────────────────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
    required this.onInsertNewline,
    required this.onNewChat,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onInsertNewline;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: onNewChat,
            icon: Icon(Icons.add_circle_outline_rounded,
                color: onSurface.withOpacity(0.38)),
            tooltip: 'New conversation',
          ),
          Expanded(
            child: KeyboardListener(
              focusNode: FocusNode(), // separate listener focus
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  final isEnter = event.logicalKey == LogicalKeyboardKey.enter;

                  if (isEnter && !HardwareKeyboard.instance.isShiftPressed) {
                    if (!isSending) onSend();
                  } else if (isEnter &&
                      HardwareKeyboard.instance.isShiftPressed) {
                    onInsertNewline();
                  }
                }
              },
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                style: TextStyle(color: onSurface, fontSize: 15),
                maxLines: 5,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:
                  'Ask a question about your documents..',
                  hintStyle: TextStyle(
                      color: onSurface.withOpacity(0.35),
                      fontSize: 13),
                  filled: true,
                  fillColor: onSurface.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          const Gap(8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: isSending
                ? Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            )
                : GestureDetector(
              onTap: onSend,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty chat state ───────────────────────────────────────────────────────────
class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView({required this.collection});
  final Collection collection;

  static const _suggestions = [
    'What are the main topics covered?',
    'Summarise the key findings.',
    'What data or statistics are mentioned?',
    'Who are the main people or organisations discussed?',
    'What recommendations are made?',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Gap(20),
        Icon(Icons.auto_awesome_rounded,
            size: 48, color: cs.primary.withOpacity(0.6)),
        const Gap(12),
        Text(
          'Ask anything about\n"${collection.name}"',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4),
        ),
        const Gap(8),
        Text(
          '${collection.documentCount} document(s) · '
              '${collection.chunkCount} chunks indexed',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: onSurface.withOpacity(0.45), fontSize: 13),
        ),
        const Gap(32),
        Text(
          'Suggested questions',
          style: TextStyle(
              color: onSurface.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const Gap(10),
        ..._suggestions.map((s) => _SuggestionChip(label: s)),
      ],
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final chatState =
          context.findAncestorStateOfType<_ChatScreenState>();
          if (chatState != null) {
            chatState._textController.text = label;
            chatState._focusNode.requestFocus();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: onSurface.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 16,
                  color: onSurface.withOpacity(0.38)),
              const Gap(10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: onSurface.withOpacity(0.75),
                        fontSize: 14)),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: onSurface.withOpacity(0.25)),
            ],
          ),
        ),
      ),
    );
  }
}