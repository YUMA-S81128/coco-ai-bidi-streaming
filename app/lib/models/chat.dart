import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat.freezed.dart';
part 'chat.g.dart';

/// チャットセッションのモデル。
@freezed
abstract class Chat with _$Chat {
  const Chat._(); // カスタムメソッド用のプライベートコンストラクタ

  const factory Chat({
    required String id,
    required String userId,
    required String title,
    String? sessionId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Chat;

  /// JSON からの変換。
  factory Chat.fromJson(Map<String, dynamic> json) => _$ChatFromJson(json);

  /// Firestore ドキュメントから変換。
  factory Chat.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Chat(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      sessionId: data['sessionId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
