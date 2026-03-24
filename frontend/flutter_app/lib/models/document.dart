class DocumentModel {
  const DocumentModel({
    required this.id,
    required this.collectionId,
    required this.filename,
    required this.originalFilename,
    required this.fileType,
    required this.fileSize,
    required this.chunkCount,
    required this.isIndexed,
    required this.createdAt,
  });

  final String id;
  final String collectionId;
  final String filename;
  final String originalFilename;
  final String fileType;
  final int fileSize;
  final int chunkCount;
  final bool isIndexed;
  final DateTime createdAt;

  factory DocumentModel.fromJson(Map<String, dynamic> json) => DocumentModel(
    id: json['id'] as String,
    collectionId: json['collection_id'] as String,
    filename: json['filename'] as String,
    originalFilename: json['original_filename'] as String,
    fileType: json['file_type'] as String? ?? '',
    fileSize: json['file_size'] as int? ?? 0,
    chunkCount: json['chunk_count'] as int? ?? 0,
    isIndexed: json['is_indexed'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  String get fileSizeFormatted {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get fileTypeIcon {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return '📄';
      case 'md':
        return '📝';
      case 'txt':
        return '📃';
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'tiff':
      case 'bmp':
      case 'webp':
        return '🖼️';
      default:
        return '📁';
    }
  }
}