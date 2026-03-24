import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';

// ── Conversations list ────────────────────────────────────────────────────────
final conversationsProvider = AsyncNotifierProviderFamily<ConversationsNotifier,
    List<Conversation>, String>(ConversationsNotifier.new);

class ConversationsNotifier
    extends FamilyAsyncNotifier<List<Conversation>, String> {
  @override
  Future<List<Conversation>> build(String collectionId) =>
      ref.read(chatRepositoryProvider).getConversations(collectionId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => ref.read(chatRepositoryProvider).getConversations(arg),
    );
  }

  Future<void> delete(String conversationId) async {
    await ref.read(chatRepositoryProvider).deleteConversation(conversationId);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((c) => c.id != conversationId)
          .toList(),
    );
  }
}

// ── Active conversation ID ────────────────────────────────────────────────────
final activeConversationIdProvider = StateProvider<String?>((ref) => null);

// ── Chat messages + streaming ─────────────────────────────────────────────────
final chatProvider =
AsyncNotifierProviderFamily<ChatNotifier, List<ChatMessage>, String>(
  ChatNotifier.new,
);

class ChatNotifier extends FamilyAsyncNotifier<List<ChatMessage>, String> {
  String? _conversationId;

  @override
  Future<List<ChatMessage>> build(String collectionId) async =>
      <ChatMessage>[];

  String? get conversationId => _conversationId;

  /// Load messages from an existing conversation.
  Future<void> loadConversation(String conversationId) async {
    _conversationId = conversationId;
    state = const AsyncLoading();
    final messages = await ref
        .read(chatRepositoryProvider)
        .getMessages(conversationId);
    state = AsyncData(messages);
  }

  /// Start a fresh conversation (clears messages + conversationId).
  void newConversation() {
    _conversationId = null;
    state = const AsyncData(<ChatMessage>[]);
    ref.read(activeConversationIdProvider.notifier).state = null;
  }

  /// Send a message and stream the response token by token.
  Future<void> sendMessage(String text) async {
    final userMessage = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
    );

    // Start with user message + empty placeholder
    final withUser = <ChatMessage>[
      ...(state.valueOrNull ?? <ChatMessage>[]),
      userMessage,
    ];
    state = AsyncData(withUser);

    final placeholder = ChatMessage.streamingPlaceholder();
    state = AsyncData(<ChatMessage>[...withUser, placeholder]);

    // We track the streaming state locally and replace the placeholder
    // by index on every update — never mutate, always copyWith + reassign
    String streamingContent = '';
    final streamingSources = <SourceRef>[];

    try {
      final stream = ref.read(chatRepositoryProvider).sendMessage(
        collectionId: arg,
        message: text,
        conversationId: _conversationId,
      );

      await for (final event in stream) {
        final type = event['type'] as String?;
        final data = event['data'];

        switch (type) {
          case 'conversation_id':
            _conversationId = data as String;
            ref.read(activeConversationIdProvider.notifier).state =
                _conversationId;

          case 'source':
            streamingSources
                .add(SourceRef.fromJson(data as Map<String, dynamic>));
            _replacePlaceholder(
              placeholder.id,
              content: streamingContent,
              sources: List<SourceRef>.from(streamingSources),
              isStreaming: true,
            );

          case 'token':
            streamingContent += data as String;
            _replacePlaceholder(
              placeholder.id,
              content: streamingContent,
              sources: List<SourceRef>.from(streamingSources),
              isStreaming: true,
            );

          case 'done':
            _replacePlaceholder(
              placeholder.id,
              content: streamingContent,
              sources: List<SourceRef>.from(streamingSources),
              isStreaming: false,
            );
            ref.read(conversationsProvider(arg).notifier).refresh();

          case 'error':
            _replacePlaceholder(
              placeholder.id,
              content: '⚠️ ${data as String}',
              sources: const <SourceRef>[],
              isStreaming: false,
            );
        }
      }
    } catch (e) {
      _replacePlaceholder(
        placeholder.id,
        content: '⚠️ Connection error: $e',
        sources: const <SourceRef>[],
        isStreaming: false,
      );
    }
  }

  /// Replace the placeholder message by ID with a new immutable instance.
  /// This guarantees Riverpod detects the state change and rebuilds the UI.
  void _replacePlaceholder(
      String placeholderId, {
        required String content,
        required List<SourceRef> sources,
        required bool isStreaming,
      }) {
    final current = List<ChatMessage>.from(state.valueOrNull ?? <ChatMessage>[]);
    final idx = current.indexWhere((m) => m.id == placeholderId);
    if (idx == -1) return;

    // Replace with a brand-new ChatMessage instance via copyWith
    current[idx] = current[idx].copyWith(
      content: content,
      sources: sources,
      isStreaming: isStreaming,
    );

    // Assign new list reference so Riverpod triggers rebuild
    state = AsyncData(List<ChatMessage>.from(current));
  }
}
