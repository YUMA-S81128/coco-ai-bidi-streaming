import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../logic/chat_provider.dart';
import 'message_list.dart';

/// チャットエリアウィジェット。
///
/// メインのチャットコンテンツエリア。
/// メッセージリストとマイクコントロールを含む。
class ChatArea extends ConsumerWidget {
  const ChatArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatProvider);

    return Column(
      children: [
        // ステータスバー（接続中のみ表示）
        if (chatState.status == ChatStatus.connecting)
          _buildConnectingIndicator(),

        // エラー表示
        if (chatState.status == ChatStatus.error)
          _buildErrorBanner(chatState.errorMessage),

        // メッセージ表示エリア
        Expanded(child: MessageList(chatId: chatState.chatId)),

        // コントロールエリア（マイクボタン）
        _MicrophoneControl(
          status: chatState.status,
          onTap: () => _handleMicTap(ref, chatState),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildConnectingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Text('接続中...', style: TextStyle(color: AppColors.warning)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String? errorMessage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage ?? 'エラーが発生しました',
              style: TextStyle(color: AppColors.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMicTap(WidgetRef ref, ChatState state) {
    final notifier = ref.read(chatProvider.notifier);

    if (state.status == ChatStatus.recording) {
      notifier.stopRecording();
    } else if (state.status == ChatStatus.connected) {
      notifier.startRecording();
    } else if (state.status == ChatStatus.disconnected) {
      // 切断状態: chatId があれば再接続+録音開始、なければ新規チャット
      if (state.chatId != null) {
        notifier.resumeAndStartRecording(state.chatId!);
      } else {
        notifier.startNewChat();
      }
    } else if (state.status == ChatStatus.error) {
      // エラー時は再接続
      if (state.chatId != null) {
        notifier.resumeChat(state.chatId!);
      } else {
        notifier.startNewChat();
      }
    }
  }
}

/// マイクコントロールウィジェット。
class _MicrophoneControl extends StatelessWidget {
  final ChatStatus status;
  final VoidCallback onTap;

  const _MicrophoneControl({required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRecording = status == ChatStatus.recording;
    final isConnecting = status == ChatStatus.connecting;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // マイクボタン
          GestureDetector(
            onTap: isConnecting ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getButtonColor(),
                boxShadow: [
                  BoxShadow(
                    color: _getButtonColor().withValues(alpha: 0.3),
                    blurRadius: isRecording ? 16 : 8,
                    spreadRadius: isRecording ? 3 : 1,
                  ),
                ],
              ),
              child: isConnecting
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          // ステータステキスト
          Text(
            _getStatusText(),
            style: TextStyle(color: _getStatusTextColor(), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor() {
    return switch (status) {
      ChatStatus.disconnected => AppColors.primary,
      ChatStatus.connecting => Colors.grey,
      ChatStatus.connected => AppColors.primary,
      ChatStatus.recording => AppColors.error,
      ChatStatus.error => AppColors.warning,
    };
  }

  String _getStatusText() {
    return switch (status) {
      ChatStatus.disconnected => '接続待機中...',
      ChatStatus.connecting => '接続中...',
      ChatStatus.connected => 'タップして会話を開始',
      ChatStatus.recording => '録音中... タップして停止',
      ChatStatus.error => 'タップして再接続',
    };
  }

  Color _getStatusTextColor() {
    return switch (status) {
      ChatStatus.recording => AppColors.error,
      ChatStatus.error => AppColors.warning,
      _ => AppColors.textSecondary,
    };
  }
}
