import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_state.freezed.dart';

/// チャットセッションの接続状態。
enum ChatStatus {
  /// 未接続（初期状態または切断後）
  disconnected,

  /// 接続処理中
  connecting,

  /// 接続完了（録音待機中）
  connected,

  /// 録音中
  recording,

  /// エラー発生
  error,
}

/// チャットセッションの状態。
@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default(ChatStatus.disconnected) ChatStatus status,
    String? chatId,
    String? errorMessage,
  }) = _ChatState;
}
