import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/collection.dart';

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onDelete,
    this.isSelected = false,
  });

  final Collection collection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? cs.primary.withOpacity(0.12) : theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? cs.primary : cs.outline.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_rounded,
                        color: cs.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeago.format(collection.updatedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: onSurface.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: onSurface.withOpacity(0.35), size: 25),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (collection.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  collection.description,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: onSurface.withOpacity(0.55)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _Stat(
                    icon: Icons.description_outlined,
                    label: '${collection.documentCount} docs',
                    color: onSurface.withOpacity(0.45),
                  ),
                  const SizedBox(width: 16),
                  _Stat(
                    icon: Icons.auto_awesome_mosaic_outlined,
                    label: '${collection.chunkCount} chunks',
                    color: onSurface.withOpacity(0.45),
                  ),
                  const Spacer(),
                  if (collection.isIndexed)
                    _Badge(label: 'Indexed', color: cs.secondary)
                  else
                    _Badge(
                        label: 'Empty',
                        color: onSurface.withOpacity(0.3)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 12)),
    ],
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600)),
  );
}
