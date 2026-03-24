import 'package:flutter/material.dart';
import '../models/message.dart';

class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.source});
  final SourceRef source;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.article_outlined,
                  size: 13, color: cs.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  source.filename,
                  style: TextStyle(
                    color: cs.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (source.pageNumber != null) ...[
            const SizedBox(height: 2),
            Text(
              'Page ${source.pageNumber}',
              style: TextStyle(
                  color: onSurface.withOpacity(0.4),
                  fontSize: 10),
            ),
          ],
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              source.excerpt,
              style: TextStyle(
                  color: onSurface.withOpacity(0.6),
                  fontSize: 11,
                  height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                source.scorePercent,
                style: TextStyle(
                    color: cs.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
