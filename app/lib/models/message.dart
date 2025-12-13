import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// チャットメッセージのモデル。
@freezed
abstract class Message with _$Message {
  const Message._(); // カスタムメソッド用のプライベートコンストラクタ

  const factory Message({
    required String id,
    required String role, // "user" | "model" | "tool"
    required String content,
    List<ToolCall>? toolCalls,
    DateTime? createdAt,
  }) = _Message;

  /// JSON からの変換。
  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  /// Firestore ドキュメントから変換。
  factory Message.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Message(
      id: doc.id,
      role: data['role'] as String? ?? 'user',
      content: data['content'] as String? ?? '',
      toolCalls: (data['toolCalls'] as List<dynamic>?)
          ?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// ツールコールの情報。
@freezed
abstract class ToolCall with _$ToolCall {
  const factory ToolCall({required String toolName, String? jobId}) = _ToolCall;

  factory ToolCall.fromJson(Map<String, dynamic> json) =>
      _$ToolCallFromJson(json);
}
