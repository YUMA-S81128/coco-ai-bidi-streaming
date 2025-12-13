import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/chat_provider.dart';
import 'image_display.dart';

/// チャット（音声会話）画面。
///
/// [chatId] が null の場合は新規チャットを開始し、
/// 指定された場合は既存チャットを再開する。
class ChatScreen extends ConsumerStatefulWidget {
  final String? chatId;

  const ChatScreen({super.key, this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // 音声デバイスの初期化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(chatState)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 接続中の場合は切断してから戻る
            if (chatState.status != ChatStatus.disconnected) {
              ref.read(chatProvider.notifier).disconnect();
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          // ステータスバー
          _StatusBar(status: chatState.status, error: chatState.errorMessage),

          // 画像表示エリア
          Expanded(child: ImageDisplay(chatId: chatState.chatId)),

          // コントロールエリア
          _ControlArea(
            status: chatState.status,
            onToggle: () => _handleToggle(chatState),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _getTitle(ChatState state) {
    if (state.chatId != null) {
      return 'チャット中';
    }
    return 'Gemini Live';
  }

  void _handleToggle(ChatState state) {
    final notifier = ref.read(chatProvider.notifier);

    if (state.status == ChatStatus.recording) {
      notifier.stopRecording();
    } else if (state.status == ChatStatus.disconnected) {
      // 新規チャットまたは既存チャットの再開
      if (widget.chatId != null) {
        notifier.resumeChat(widget.chatId!);
      } else {
        notifier.startNewChat();
      }
    } else if (state.status == ChatStatus.connected) {
      notifier.startRecording();
    }
  }
}

/// ステータス表示バー。
class _StatusBar extends StatelessWidget {
  final ChatStatus status;
  final String? error;

  const _StatusBar({required this.status, this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: _getStatusColor(status),
      width: double.infinity,
      child: Text(
        _getStatusText(),
        style: const TextStyle(color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getStatusText() {
    final statusText = switch (status) {
      ChatStatus.disconnected => '未接続',
      ChatStatus.connecting => '接続中...',
      ChatStatus.connected => '接続完了',
      ChatStatus.recording => '録音中',
      ChatStatus.error => 'エラー',
    };

    if (error != null) {
      return '$statusText: $error';
    }
    return statusText;
  }

  Color _getStatusColor(ChatStatus status) {
    return switch (status) {
      ChatStatus.disconnected => Colors.grey,
      ChatStatus.connecting => Colors.orange,
      ChatStatus.connected => Colors.green,
      ChatStatus.recording => Colors.red,
      ChatStatus.error => Colors.redAccent,
    };
  }
}

/// マイクコントロールエリア。
class _ControlArea extends StatelessWidget {
  final ChatStatus status;
  final VoidCallback onToggle;

  const _ControlArea({required this.status, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isRecording = status == ChatStatus.recording;
    final isConnecting = status == ChatStatus.connecting;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          InkWell(
            onTap: isConnecting ? null : onToggle,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnecting
                    ? Colors.grey
                    : (isRecording ? Colors.red : Colors.blue),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: isConnecting
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(_getButtonLabel()),
        ],
      ),
    );
  }

  String _getButtonLabel() {
    return switch (status) {
      ChatStatus.disconnected => 'タップして開始',
      ChatStatus.connecting => '接続中...',
      ChatStatus.connected => 'タップして録音',
      ChatStatus.recording => 'タップして停止',
      ChatStatus.error => 'タップして再接続',
    };
  }
}
