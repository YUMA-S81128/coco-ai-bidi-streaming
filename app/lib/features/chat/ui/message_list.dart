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

        // 最新の画像ジョブのみ取得（createdAt降順で最初の1件）
        final latestImageJob = imageJobsAsync.when(
          data: (jobs) => jobs.isNotEmpty ? jobs.first : null,
          loading: () => null,
          error: (_, __) => null,
        );

        // メッセージ + 最新画像ジョブ（存在する場合）
        final hasImage = latestImageJob != null;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: messages.length + (hasImage ? 1 : 0),
          itemBuilder: (context, index) {
            // メッセージを先に表示
            if (index < messages.length) {
              final message = messages[index];
              return MessageBubble(message: message);
            }

            // 最新の画像ジョブを最後に表示
            return _buildImageJobCard(context, latestImageJob!);
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

  /// 画像ジョブをカードとして表示する。
  Widget _buildImageJobCard(BuildContext context, ImageJob job) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // 画像部分を MessageBubble に委譲（プロンプトは非表示）
      child: MessageBubble(
        message: Message(id: job.id, role: 'model', content: ''),
        imageJob: job,
      ),
    );
  }

  Widget _buildWelcomeView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mic, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Coco-Ai へようこそ',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
}
