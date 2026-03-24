import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/dio_client.dart';
import '../core/exceptions.dart';
import '../models/document.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
      (ref) => DocumentRepository(ref.watch(dioClientProvider)),
);

class DocumentRepository {
  const DocumentRepository(this._client);
  final DioClient _client;

  Future<List<DocumentModel>> getAll(String collectionId) async {
    try {
      final res = await _client.get<List<dynamic>>(
        '/collections/$collectionId/documents',
      );
      return (res.data ?? [])
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to load documents');
    }
  }

  /// Upload multiple files to a collection.
  /// [onProgress] receives (sent bytes, total bytes) for a progress indicator.
  Future<List<DocumentModel>> uploadFiles(
      String collectionId,
      List<({String path, String name})> files, {
        void Function(int sent, int total)? onProgress,
      }) async {
    try {
      // Use the batch endpoint for multiple files
      final formData = FormData();
      for (final file in files) {
        formData.files.add(MapEntry(
          'files',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }

      final endpoint = files.length == 1
          ? '/collections/$collectionId/documents'
          : '/collections/$collectionId/documents/batch';

      // Single file uses 'file' field, batch uses 'files'
      FormData data;
      if (files.length == 1) {
        data = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            files.first.path,
            filename: files.first.name,
          ),
        });
      } else {
        data = formData;
      }

      final res = await _client.postForm<List<dynamic>>(
        endpoint,
        formData: data,
        onSendProgress: onProgress,
      );

      return (res.data ?? [])
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to upload files');
    }
  }

  Future<void> delete(String collectionId, String documentId) async {
    try {
      await _client.delete('/collections/$collectionId/documents/$documentId');
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to delete document');
    }
  }

  Future<Map<String, dynamic>> reindex(String collectionId) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/collections/$collectionId/reindex',
      );
      return res.data!;
    } on DioException catch (e) {
      throw e.error as AppException? ?? ApiException(e.message ?? 'Failed to reindex');
    }
  }
}