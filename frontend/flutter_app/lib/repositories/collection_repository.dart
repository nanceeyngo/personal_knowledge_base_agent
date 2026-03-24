import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../core/exceptions.dart';
import '../models/collection.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>(
      (ref) => CollectionRepository(ref.watch(dioClientProvider)),
);

class CollectionRepository {
  const CollectionRepository(this._client);
  final DioClient _client;

  Future<List<Collection>> getAll() async {
    try {
      final res = await _client.get<List<dynamic>>('/collections');
      return (res.data ?? [])
          .map((e) => Collection.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to load collections');
    }
  }

  Future<Collection> create(String name, {String description = ''}) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/collections',
        data: {'name': name, 'description': description},
      );
      return Collection.fromJson(res.data!);
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to create collection');
    }
  }

  Future<void> delete(String collectionId) async {
    try {
      await _client.delete('/collections/$collectionId');
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to delete collection');
    }
  }

  Future<Collection> update(String collectionId, String name, {String? description}) async {
    try {
      final res = await _client.patch<Map<String, dynamic>>(
        '/collections/$collectionId',
        data: {'name': name, 'description': description ?? ''},
      );
      return Collection.fromJson(res.data!);
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to update collection');
    }
  }
}