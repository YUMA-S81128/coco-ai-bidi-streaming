// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  role: json['role'] as String,
  content: json['content'] as String,
  toolCalls: (json['toolCalls'] as List<dynamic>?)
      ?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
      .toList(),
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'role': instance.role,
  'content': instance.content,
  'toolCalls': instance.toolCalls,
  'createdAt': instance.createdAt?.toIso8601String(),
};

_ToolCall _$ToolCallFromJson(Map<String, dynamic> json) => _ToolCall(
  toolName: json['toolName'] as String,
  jobId: json['jobId'] as String?,
);

Map<String, dynamic> _$ToolCallToJson(_ToolCall instance) => <String, dynamic>{
  'toolName': instance.toolName,
  'jobId': instance.jobId,
};
