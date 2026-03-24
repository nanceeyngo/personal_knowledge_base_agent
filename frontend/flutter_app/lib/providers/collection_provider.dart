import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/collection.dart';
import '../repositories/collection_repository.dart';

// ── Collections list ──────────────────────────────────────────────────────────
final collectionsProvider =
AsyncNotifierProvider<CollectionsNotifier, List<Collection>>(
  CollectionsNotifier.new,
);

class CollectionsNotifier extends AsyncNotifier<List<Collection>> {
  @override
  Future<List<Collection>> build() => _fetch();

  Future<List<Collection>> _fetch() =>
      ref.read(collectionRepositoryProvider).getAll();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<Collection?> create(String name, {String description = ''}) async {
    try {
      final collection = await ref
          .read(collectionRepositoryProvider)
          .create(name, description: description);

      // Prepend new collection to the list
      state = AsyncData([collection, ...state.valueOrNull ?? []]);
      return collection;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<void> delete(String collectionId) async {
    await ref.read(collectionRepositoryProvider).delete(collectionId);
    state = AsyncData(
      (state.valueOrNull ?? [])
          .where((c) => c.id != collectionId)
          .toList(),
    );
  }
}

// ── Selected collection ───────────────────────────────────────────────────────
final selectedCollectionProvider = StateProvider<Collection?>((ref) => null);