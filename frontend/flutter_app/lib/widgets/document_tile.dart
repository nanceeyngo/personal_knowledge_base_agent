import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/document.dart';

class DocumentTile extends StatelessWidget {
  const DocumentTile({
    super.key,
    required this.document,
    required this.onDelete,
  });

  final DocumentModel document;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    return Container(
      margin:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: onSurface.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // File type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(document.fileTypeIcon,
                style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.originalFilename,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      document.fileSizeFormatted,
                      style: TextStyle(
                          color: onSurface.withOpacity(0.45),
                          fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${document.chunkCount} chunks',
                      style: TextStyle(
                          color: onSurface.withOpacity(0.45),
                          fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      timeago.format(document.createdAt),
                      style: TextStyle(
                          color: onSurface.withOpacity(0.45),
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (document.isIndexed)
            Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(
                  horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Indexed',
                style: TextStyle(
                    color: cs.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline_rounded,
                color: onSurface.withOpacity(0.3), size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
