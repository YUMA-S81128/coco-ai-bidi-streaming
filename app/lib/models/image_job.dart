import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_job.freezed.dart';
part 'image_job.g.dart';

/// 画像生成ジョブのモデル。
@freezed
abstract class ImageJob with _$ImageJob {
  const ImageJob._(); // カスタムメソッド用のプライベートコンストラクタ

  const factory ImageJob({
    required String id,
    required String userId,
    required String chatId,
    String? messageId,
    required String prompt,
    required String status,
    String? imageUrl,
    String? error,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ImageJob;

  /// JSON からの変換。
  factory ImageJob.fromJson(Map<String, dynamic> json) =>
      _$ImageJobFromJson(json);

  /// Firestore ドキュメントから変換。
  factory ImageJob.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ImageJob(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      chatId: data['chatId'] as String? ?? '',
      messageId: data['messageId'] as String?,
      prompt: data['prompt'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      imageUrl: data['imageUrl'] as String?,
      error: data['error'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
