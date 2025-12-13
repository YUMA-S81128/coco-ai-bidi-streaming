// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_job.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ImageJob _$ImageJobFromJson(Map<String, dynamic> json) => _ImageJob(
  id: json['id'] as String,
  userId: json['userId'] as String,
  chatId: json['chatId'] as String,
  messageId: json['messageId'] as String?,
  prompt: json['prompt'] as String,
  status: json['status'] as String,
  imageUrl: json['imageUrl'] as String?,
  error: json['error'] as String?,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$ImageJobToJson(_ImageJob instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'chatId': instance.chatId,
  'messageId': instance.messageId,
  'prompt': instance.prompt,
  'status': instance.status,
  'imageUrl': instance.imageUrl,
  'error': instance.error,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
