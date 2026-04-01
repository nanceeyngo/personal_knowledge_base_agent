import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/config.dart';
import '../../models/collection.dart';
import '../../providers/document_provider.dart';
import '../../widgets/document_tile.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen(
      {super.key, required this.collection});
  final Collection collection;

  @override
  ConsumerState<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState
    extends ConsumerState<CollectionDetailScreen> {
  double _uploadProgress = 0;
  bool _isUploading = false;
  String? _uploadError;

  @override
  Widget build(BuildContext context) {
    final docsAsync =
    ref.watch(documentsProvider(widget.collection.id));
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final onSurface = cs.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.collection.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Documents',
                style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withOpacity(0.45))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-index all documents',
            onPressed: () => _reindex(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _UploadArea(
            isUploading: _isUploading,
            progress: _uploadProgress,
            error: _uploadError,
            onPickFiles: () => _pickAndUpload(context),
          ),
          const Divider(height: 1),
          Expanded(
            child: docsAsync.when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(e.toString(),
                    style:
                    const TextStyle(color: Colors.redAccent)),
              ),
              data: (docs) => docs.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file_rounded,
                        size: 48,
                        color: cs.primary.withOpacity(0.4)),
                    const Gap(12),
                    Text('No documents yet',
                        style: TextStyle(
                            color:
                            onSurface.withOpacity(0.45))),
                    const Gap(8),
                    Text(
                      'Upload PDF, TXT, MD, or image files above',
                      style: TextStyle(
                          color: onSurface.withOpacity(0.3),
                          fontSize: 12),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                onRefresh: () => ref
                    .read(documentsProvider(
                    widget.collection.id)
                    .notifier)
                    .refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                      top: 8, bottom: 24),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => DocumentTile(
                    document: docs[i],
                    onDelete: () => _confirmDelete(
                        context,
                        docs[i].id,
                        docs[i].originalFilename),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: AppConfig.allowedExtensions,
    );
    if (result == null || result.files.isEmpty) return;

    for (final f in result.files) {
      if (f.size / (1024 * 1024) > AppConfig.maxFileSizeMb) {
        _showSnack(context,
            '${f.name} exceeds ${AppConfig.maxFileSizeMb}MB limit',
            isError: true);
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
      _uploadError = null;
    });

    try {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => (path: f.path!, name: f.name))
          .toList();

      await ref
          .read(documentsProvider(widget.collection.id).notifier)
          .uploadFiles(files, (progress) {
        setState(() => _uploadProgress = progress);
      });

      if (context.mounted) {
        _showSnack(context,
            '${files.length} file(s) uploaded successfully ✓');
      }
    } catch (e) {
      setState(() => _uploadError = e.toString());
      if (context.mounted) {
        _showSnack(context, 'Upload failed: $e', isError: true);
      }
    } finally {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });
    }
  }

  Future<void> _reindex(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Re-index Collection'),
        content: const Text(
          'This will re-embed all documents from scratch. '
              'Use this after changing chunk or embedding settings. '
              'It may take a few minutes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Re-index'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('Reindexing... Please wait')),
            ],
          ),
        ),
      );
      try {
        final msg = await ref
            .read(documentsProvider(widget.collection.id).notifier)
            .reindex();
        if (context.mounted) {
          Navigator.pop(context);
          _showSnack(context, msg ?? 'Re-indexed successfully ✓');
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          _showSnack(context, 'Reindex failed: $e', isError: true);
        }
      }
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Document'),
        content:
        Text('Remove "$name" from this collection?'),
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
      await ref
          .read(documentsProvider(widget.collection.id).notifier)
          .delete(docId);
    }
  }

  void _showSnack(BuildContext context, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? Colors.redAccent : Colors.green.shade700,
    ));
  }
}

// ── Upload area ────────────────────────────────────────────────────────────────
class _UploadArea extends StatelessWidget {
  const _UploadArea({
    required this.isUploading,
    required this.progress,
    required this.error,
    required this.onPickFiles,
  });

  final bool isUploading;
  final double progress;
  final String? error;
  final VoidCallback onPickFiles;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final onSurface = cs.onSurface;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GestureDetector(
        onTap: isUploading ? null : onPickFiles,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
              vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error != null
                  ? Colors.redAccent
                  : cs.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: isUploading
              ? Column(
            children: [
              LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                backgroundColor:
                cs.primary.withOpacity(0.2),
                valueColor:
                AlwaysStoppedAnimation(cs.primary),
                borderRadius: BorderRadius.circular(4),
              ),
              const Gap(10),
              Text(
                progress > 0
                    ? 'Uploading… ${(progress * 100).toInt()}%'
                    : 'Processing…',
                style: TextStyle(
                    color: cs.primary, fontSize: 13),
              ),
            ],
          )
              : Column(
            children: [
              Icon(Icons.cloud_upload_outlined,
                  size: 36,
                  color: cs.primary.withOpacity(0.7)),
              const Gap(8),
              Text(
                'Tap to upload documents',
                style: TextStyle(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15),
              ),
              const Gap(4),
              Text(
                'PDF, TXT, MD, PNG, JPG · Max 50MB',
                style: TextStyle(
                    color: onSurface.withOpacity(0.4),
                    fontSize: 12),
              ),
              if (error != null) ...[
                const Gap(8),
                Text(error!,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
