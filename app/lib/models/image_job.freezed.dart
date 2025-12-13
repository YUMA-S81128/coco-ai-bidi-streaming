// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'image_job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ImageJob {

 String get id; String get userId; String get chatId; String? get messageId; String get prompt; String get status; String? get imageUrl; String? get error; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of ImageJob
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ImageJobCopyWith<ImageJob> get copyWith => _$ImageJobCopyWithImpl<ImageJob>(this as ImageJob, _$identity);

  /// Serializes this ImageJob to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ImageJob&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.error, error) || other.error == error)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,chatId,messageId,prompt,status,imageUrl,error,createdAt,updatedAt);

@override
String toString() {
  return 'ImageJob(id: $id, userId: $userId, chatId: $chatId, messageId: $messageId, prompt: $prompt, status: $status, imageUrl: $imageUrl, error: $error, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $ImageJobCopyWith<$Res>  {
  factory $ImageJobCopyWith(ImageJob value, $Res Function(ImageJob) _then) = _$ImageJobCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String chatId, String? messageId, String prompt, String status, String? imageUrl, String? error, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$ImageJobCopyWithImpl<$Res>
    implements $ImageJobCopyWith<$Res> {
  _$ImageJobCopyWithImpl(this._self, this._then);

  final ImageJob _self;
  final $Res Function(ImageJob) _then;

/// Create a copy of ImageJob
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? chatId = null,Object? messageId = freezed,Object? prompt = null,Object? status = null,Object? imageUrl = freezed,Object? error = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ImageJob].
extension ImageJobPatterns on ImageJob {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ImageJob value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ImageJob() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ImageJob value)  $default,){
final _that = this;
switch (_that) {
case _ImageJob():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ImageJob value)?  $default,){
final _that = this;
switch (_that) {
case _ImageJob() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String chatId,  String? messageId,  String prompt,  String status,  String? imageUrl,  String? error,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ImageJob() when $default != null:
return $default(_that.id,_that.userId,_that.chatId,_that.messageId,_that.prompt,_that.status,_that.imageUrl,_that.error,_that.createdAt,_that.updatedAt);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String chatId,  String? messageId,  String prompt,  String status,  String? imageUrl,  String? error,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ImageJob():
return $default(_that.id,_that.userId,_that.chatId,_that.messageId,_that.prompt,_that.status,_that.imageUrl,_that.error,_that.createdAt,_that.updatedAt);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String chatId,  String? messageId,  String prompt,  String status,  String? imageUrl,  String? error,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ImageJob() when $default != null:
return $default(_that.id,_that.userId,_that.chatId,_that.messageId,_that.prompt,_that.status,_that.imageUrl,_that.error,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ImageJob extends ImageJob {
  const _ImageJob({required this.id, required this.userId, required this.chatId, this.messageId, required this.prompt, required this.status, this.imageUrl, this.error, this.createdAt, this.updatedAt}): super._();
  factory _ImageJob.fromJson(Map<String, dynamic> json) => _$ImageJobFromJson(json);

@override final  String id;
@override final  String userId;
@override final  String chatId;
@override final  String? messageId;
@override final  String prompt;
@override final  String status;
@override final  String? imageUrl;
@override final  String? error;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of ImageJob
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ImageJobCopyWith<_ImageJob> get copyWith => __$ImageJobCopyWithImpl<_ImageJob>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ImageJobToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ImageJob&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.prompt, prompt) || other.prompt == prompt)&&(identical(other.status, status) || other.status == status)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.error, error) || other.error == error)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,chatId,messageId,prompt,status,imageUrl,error,createdAt,updatedAt);

@override
String toString() {
  return 'ImageJob(id: $id, userId: $userId, chatId: $chatId, messageId: $messageId, prompt: $prompt, status: $status, imageUrl: $imageUrl, error: $error, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ImageJobCopyWith<$Res> implements $ImageJobCopyWith<$Res> {
  factory _$ImageJobCopyWith(_ImageJob value, $Res Function(_ImageJob) _then) = __$ImageJobCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String chatId, String? messageId, String prompt, String status, String? imageUrl, String? error, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$ImageJobCopyWithImpl<$Res>
    implements _$ImageJobCopyWith<$Res> {
  __$ImageJobCopyWithImpl(this._self, this._then);

  final _ImageJob _self;
  final $Res Function(_ImageJob) _then;

/// Create a copy of ImageJob
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? chatId = null,Object? messageId = freezed,Object? prompt = null,Object? status = null,Object? imageUrl = freezed,Object? error = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_ImageJob(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,prompt: null == prompt ? _self.prompt : prompt // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
