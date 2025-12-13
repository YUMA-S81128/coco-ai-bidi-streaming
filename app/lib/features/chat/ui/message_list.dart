import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../logic/firestore_providers.dart';
import 'message_bubble.dart';

/// メッセージリストウィジェット。
///
/// LLMからのテキストレスポンスと画像をチャット形式で表示する。
class MessageList extends ConsumerWidget {
  final String? chatId;

  const MessageList({super.key, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chatId == null) {
      return _buildWelcomeView(context);
    }

    final messagesAsync = ref.watch(messagesProvider(chatId!));
    final imageJobsAsync = ref.watch(imageJobsProvider(chatId!));

    return messagesAsync.when(
      data: (messages) {
        if (messages.isEmpty) {
          return _buildWelcomeView(context);
        }

        final imageJobs = imageJobsAsync.when(
          data: (jobs) => jobs,
          loading: () => <ImageJob>[],
          error: (_, __) => <ImageJob>[],
        );

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final imageJob = _findImageJobForMessage(message, imageJobs);

            return MessageBubble(message: message, imageJob: imageJob);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('エラーが発生しました', style: TextStyle(color: AppColors.error)),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic, size: 64, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            'Gemini Liveへようこそ',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'マイクボタンをタップして会話を始めましょう',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// メッセージに関連する画像ジョブを検索する。
  ImageJob? _findImageJobForMessage(Message message, List<ImageJob> imageJobs) {
    // message.toolCalls から関連する画像ジョブを検索
    final toolCalls = message.toolCalls;
    if (toolCalls == null || toolCalls.isEmpty) return null;

    for (final toolCall in toolCalls) {
      if (toolCall.jobId != null) {
        final job = imageJobs.where((j) => j.id == toolCall.jobId).firstOrNull;
        if (job != null) return job;
      }
    }

    // messageId でマッチングを試みる
    return imageJobs.where((j) => j.messageId == message.id).firstOrNull;
  }
}
