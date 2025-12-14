import 'dart:developer';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase Storage インスタンスを提供するプロバイダー。
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

/// [StorageService] を提供するプロバイダー。
final storageServiceProvider = Provider(
  (ref) => StorageService(ref.watch(firebaseStorageProvider)),
);

/// GCSパスからダウンロードURLを取得し、結果をキャッシュするプロバイダー。
///
/// [gsPath] は `gs://bucket/path` 形式の GCS URI。
/// 取得したHTTPS URLがキャッシュされ、同じ [gsPath] への再リクエストは
/// キャッシュから返される。
final imageUrlProvider = FutureProvider.family<String, String>((ref, gsPath) {
  // gsPath が空の場合は空文字を返す
  if (gsPath.isEmpty) {
    return Future.value('');
  }
  final storageService = ref.watch(storageServiceProvider);
  return storageService.getDownloadUrlFromGsPath(gsPath);
});

/// Firebase Cloud Storage とやり取りするためのサービスクラス。
class StorageService {
  final FirebaseStorage _storage;
  StorageService(this._storage);

  /// GCS URI (gs://...) からダウンロード可能なHTTPS URLを取得。
  ///
  /// URLが取得できない場合は空文字列を返し、エラーをログに記録。
  ///
  /// [gsPath] は `gs://bucket/path` 形式。
  Future<String> getDownloadUrlFromGsPath(String gsPath) async {
    if (gsPath.isEmpty) {
      return '';
    }
    try {
      final ref = _storage.refFromURL(gsPath);
      return await ref.getDownloadURL();
    } catch (e, s) {
      log(
        'GCSパスからのダウンロードURLの取得に失敗しました: $gsPath',
        error: e,
        stackTrace: s,
        name: 'StorageService',
      );
      return '';
    }
  }
}
