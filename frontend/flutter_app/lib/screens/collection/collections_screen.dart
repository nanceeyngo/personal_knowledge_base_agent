import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import '../../core/dio_client.dart';
import '../../main.dart';
import '../../providers/collection_provider.dart';
import '../../widgets/collection_card.dart';

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal Knowledge Base'),
        actions: [
          // ── Theme toggle button ───────────────────────────────────────────
          Consumer(
            builder: (_, ref, __) {
              final mode = ref.watch(themeModeProvider);
              return IconButton(
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                ),
                tooltip: mode == ThemeMode.dark
                    ? 'Switch to light theme'
                    : 'Switch to dark theme',
                onPressed: () {
                  ref.read(themeModeProvider.notifier).state =
                  mode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => _showSettingsSheet(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Collection'),
      ),
      body: collectionsAsync.when(
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.read(collectionsProvider.notifier).refresh(),
        ),
        data: (collections) => collections.isEmpty
            ? _EmptyView(
            onCreateTap: () =>
                _showCreateDialog(context, ref))
            : RefreshIndicator(
          onRefresh: () =>
              ref.read(collectionsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.only(
                top: 8, bottom: 100),
            itemCount: collections.length,
            itemBuilder: (_, i) {
              final col = collections[i];
              return CollectionCard(
                collection: col,
                onTap: () => ref
                    .read(selectedCollectionProvider.notifier)
                    .state = col,
                onDelete: () => _confirmDelete(
                    context, ref, col.id, col.name),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        // Use theme-aware colors inside the dialog
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('New Knowledge Base',
              style: TextStyle(fontWeight: FontWeight.w600)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Research Papers',
                    labelText: 'Name *',
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const Gap(12),
                TextFormField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Optional description',
                    labelText: 'Description',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final collection =
      await ref.read(collectionsProvider.notifier).create(
        nameCtrl.text.trim(),
        description: descCtrl.text.trim(),
      );
      if (collection != null && context.mounted) {
        ref.read(selectedCollectionProvider.notifier).state =
            collection;
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Collection'),
        content: Text(
          'Delete "$name" and all its documents and '
              'conversations? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(collectionsProvider.notifier).delete(id);
    }
  }

  void _showSettingsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettingsSheet(ref: ref),
    );
  }
}

// ── Settings sheet ─────────────────────────────────────────────────────────────
class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_SettingsSheet> createState() =>
      _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
        text: ref.read(dioClientProvider).baseUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final themeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          const Text('Settings',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          const Gap(20),
          // ── Theme segmented button ──────────────────────────────────────
          Row(
            children: [
              Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Gap(10),
              const Text('Theme',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded, size: 16),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded, size: 16),
                    label: Text('Dark'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) {
                  ref.read(themeModeProvider.notifier).state =
                      selection.first;
                },
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const Gap(20),
          const Divider(),
          const Gap(12),

          // ── Backend URL ─────────────────────────────────────────────────
          const Text('Backend URL',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const Gap(8),
          TextFormField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              hintText: 'http://10.0.2.2:8000',
            ),
          ),
          const Gap(6),
          Text(
            '• Android emulator  →  http://10.0.2.2:8000\n'
                '• Real device (same WiFi)  →  http://192.168.x.x:8000\n'
                '• Production  →  https://your-app.railway.app',
            style: TextStyle(
                fontSize: 11,
                color: onSurface.withOpacity(0.45)),
          ),
          const Gap(20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await ref
                    .read(dioClientProvider)
                    .setBaseUrl(_urlCtrl.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ref
                      .read(collectionsProvider.notifier)
                      .refresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Backend URL updated ✓')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreateTap});
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_rounded,
                size: 64,
                color: cs.primary.withOpacity(0.4)),
            const Gap(16),
            Text(
              'No knowledge bases yet',
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            Text(
              'Create a collection, upload your documents,\n'
                  'and start asking questions.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.5),
                  fontSize: 14,
                  height: 1.5),
            ),
            const Gap(24),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create your first collection'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  const _ErrorView(
      {required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Colors.redAccent),
            const Gap(16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.55),
                  fontSize: 14),
            ),
            const Gap(20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
