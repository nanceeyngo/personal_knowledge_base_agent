class Collection {
  const Collection({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    required this.documentCount,
    required this.chunkCount,
    required this.isIndexed,
  });

  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int documentCount;
  final int chunkCount;
  final bool isIndexed;

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    documentCount: json['document_count'] as int? ?? 0,
    chunkCount: json['chunk_count'] as int? ?? 0,
    isIndexed: json['is_indexed'] as bool? ?? false,
  );

  Collection copyWith({
    String? name,
    String? description,
    int? documentCount,
    int? chunkCount,
    bool? isIndexed,
  }) =>
      Collection(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt,
        updatedAt: updatedAt,
        documentCount: documentCount ?? this.documentCount,
        chunkCount: chunkCount ?? this.chunkCount,
        isIndexed: isIndexed ?? this.isIndexed,
      );
}