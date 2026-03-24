class SourceRef {
  const SourceRef({
    required this.documentId,
    required this.filename,
    required this.chunkIndex,
    required this.excerpt,
    required this.score,
    this.pageNumber,
  });

  final String documentId;
  final String filename;
  final int chunkIndex;
  final String excerpt;
  final double score;
  final int? pageNumber;

  factory SourceRef.fromJson(Map<String, dynamic> json) {
    // Robustly parse score — handles int, double, string, or null
    double parseScore(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    return SourceRef(
      documentId: json['document_id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'unknown',
      chunkIndex: (json['chunk_index'] as num?)?.toInt() ?? 0,
      excerpt: json['excerpt']?.toString() ?? '',
      score: parseScore(json['score']),
      pageNumber: (json['page_number'] as num?)?.toInt(),
    );
  }

  /// Display score as percentage — e.g. 0.823 → "82%"
  String get scorePercent {
    final pct = (score * 100).round();
    return '$pct%';
  }
}

enum MessageRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    List<SourceRef>? sources,
    DateTime? createdAt,
    this.isStreaming = false,
  }) :  //Always create a new growable list — never const []
        sources = sources != null
            ? List<SourceRef>.from(sources)
            : <SourceRef>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final MessageRole role;
  String content;                // mutable — grows as tokens stream in
  final List<SourceRef> sources; // growable, never const
  final DateTime createdAt;
  bool isStreaming;

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  /// Returns a NEW ChatMessage with updated fields.
  /// Correct Riverpod pattern — always replace, never mutate.
  ChatMessage copyWith({
    String? content,
    List<SourceRef>? sources,
    bool? isStreaming,
  }) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        sources: sources ?? List<SourceRef>.from(this.sources),
        createdAt: createdAt,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    content: json['content'] as String,
    sources: (json['sources'] as List<dynamic>? ?? [])
        .map((s) => SourceRef.fromJson(s as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  /// Creates a placeholder assistant message that will be filled by streaming.
  factory ChatMessage.streamingPlaceholder() => ChatMessage(
    id: 'streaming_${DateTime.now().millisecondsSinceEpoch}',
    role: MessageRole.assistant,
    content: '',
    isStreaming: true,
  );
}