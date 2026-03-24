class Conversation {
  const Conversation({
    required this.id,
    required this.collectionId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String collectionId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    collectionId: json['collection_id'] as String,
    title: json['title'] as String? ?? 'Conversation',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}