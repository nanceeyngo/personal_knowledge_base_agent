import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/collection.dart';
import '../../providers/collection_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../collection/collection_detail_screen.dart';
import '../collection/collections_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCollectionProvider);
    return selected == null
        ? const CollectionsScreen()
        : _ChatLayout(collection: selected);
  }
}

class _ChatLayout extends ConsumerWidget {
  const _ChatLayout({required this.collection});
  final Collection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            ref.read(selectedCollectionProvider.notifier).state = null;
            ref
                .read(chatProvider(collection.id).notifier)
                .newConversation();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(collection.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text(
              '${collection.documentCount} docs · '
                  '${collection.chunkCount} chunks',
              style: TextStyle(
                  fontSize: 11,
                  color: onSurface.withOpacity(0.45)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Conversation history',
            onPressed: () =>
                _showHistorySheet(context, ref, collection),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Manage documents',
            onPressed: () =>
                _showDocumentsSheet(context, collection),
          ),
        ],
      ),
      body: ChatScreen(collection: collection),
    );
  }

  void _showHistorySheet(
      BuildContext context, WidgetRef ref, Collection collection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _HistorySheet(collection: collection, ref: ref),
    );
  }

  void _showDocumentsSheet(
      BuildContext context, Collection collection) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          CollectionDetailScreen(collection: collection),
    ));
  }
}

// ── History bottom sheet ───────────────────────────────────────────────────────
class _HistorySheet extends ConsumerWidget {
  const _HistorySheet(
      {required this.collection, required this.ref});
  final Collection collection;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final conversationsAsync =
    widgetRef.watch(conversationsProvider(collection.id));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: onSurface.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Conversation History',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widgetRef
                      .read(chatProvider(collection.id).notifier)
                      .newConversation();
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New'),
              ),
            ],
          ),
        ),
        Expanded(
          child: conversationsAsync.when(
            loading: () =>
            const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(e.toString(),
                  style:
                  const TextStyle(color: Colors.redAccent)),
            ),
            data: (conversations) => conversations.isEmpty
                ? Center(
              child: Text(
                'No conversations yet.',
                style: TextStyle(
                    color: onSurface.withOpacity(0.4)),
              ),
            )
                : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (_, i) {
                final conv = conversations[i];
                return ListTile(
                  leading: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: onSurface.withOpacity(0.4),
                    size: 20,
                  ),
                  title: Text(
                    conv.title,
                    style: TextStyle(
                        color: onSurface, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    _formatDate(conv.updatedAt),
                    style: TextStyle(
                        color: onSurface.withOpacity(0.45),
                        fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: onSurface.withOpacity(0.35),
                    ),
                    onPressed: () {
                      widgetRef
                          .read(conversationsProvider(
                          collection.id)
                          .notifier)
                          .delete(conv.id);
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    widgetRef
                        .read(chatProvider(collection.id)
                        .notifier)
                        .loadConversation(conv.id);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
