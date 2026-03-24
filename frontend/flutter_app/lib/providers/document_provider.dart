import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document.dart';
import '../repositories/document_repository.dart';

// ── Upload progress ───────────────────────────────────────────────────────────
class UploadState {
  const UploadState({
    this.isUploading = false,
    this.progress = 0.0,
    this.error,
  });
  final bool isUploading;
  final double progress; // 0.0 – 1.0
  final String? error;

  UploadState copyWith({bool? isUploading, double? progress, String? error}) =>
      UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        error: error,
      );
}

// ── Documents for a collection ────────────────────────────────────────────────
final documentsProvider = AsyncNotifierProviderFamily<DocumentsNotifier,
    List<DocumentModel>, String>(DocumentsNotifier.new);

class DocumentsNotifier
    extends FamilyAsyncNotifier<List<DocumentModel>, String> {
  @override
  Future<List<DocumentModel>> build(String collectionId) =>
      ref.read(documentRepositoryProvider).getAll(collectionId);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
          () => ref.read(documentRepositoryProvider).getAll(arg),
    );
  }

  Future<void> uploadFiles(
      List<({String path, String name})> files,
      void Function(double) onProgress,
      ) async {
    final added = await ref.read(documentRepositoryProvider).uploadFiles(
      arg,
      files,
      onProgress: (sent, total) {
        if (total > 0) onProgress(sent / total);
      },
    );
    state = AsyncData([...added, ...state.valueOrNull ?? []]);
  }

  Future<void> delete(String documentId) async {
    await ref.read(documentRepositoryProvider).delete(arg, documentId);
    state = AsyncData(
      (state.valueOrNull ?? []).where((d) => d.id != documentId).toList(),
    );
  }

  Future<String?> reindex() async {
    final result = await ref.read(documentRepositoryProvider).reindex(arg);
    await refresh();
    return result['message'] as String?;
  }
}

// ── Upload progress state ─────────────────────────────────────────────────────
final uploadStateProvider =
StateProvider.family<UploadState, String>((ref, _) => const UploadState());