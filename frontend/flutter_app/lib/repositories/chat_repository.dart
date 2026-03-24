import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../core/exceptions.dart';
import '../models/conversation.dart';
import '../models/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
      (ref) => ChatRepository(ref.watch(dioClientProvider)),
);

class ChatRepository {
  const ChatRepository(this._client);
  final DioClient _client;

  // ── Conversations ─────────────────────────────────────────────────────────

  Future<List<Conversation>> getConversations(String collectionId) async {
    try {
      final res = await _client.get<List<dynamic>>(
        '/collections/$collectionId/conversations',
      );
      return (res.data ?? [])
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to load conversations');
    }
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    try {
      final res = await _client.get<List<dynamic>>(
        '/conversations/$conversationId',
      );
      return (res.data ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to load messages');
    }
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _client.delete('/conversations/$conversationId');
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to delete conversation');
    }
  }

  // ── SSE chat stream ───────────────────────────────────────────────────────
  /// Sends a message and returns a stream of SSE events.
  /// Event types: conversation_id | source | token | done | error
  Stream<Map<String, dynamic>> sendMessage({
    required String collectionId,
    required String message,
    String? conversationId,
  }) {
    return _client.sseStream(
      '/collections/$collectionId/chat',
      body: {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      },
    );
  }
}