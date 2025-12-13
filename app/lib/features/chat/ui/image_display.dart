import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/firestore_providers.dart';

/// 画像ジョブの状態を表示するウィジェット。
///
/// [chatId] が指定された場合はそのチャットの画像ジョブを表示し、
/// null の場合はユーザーの最新の画像ジョブを表示する。
class ImageDisplay extends ConsumerWidget {
  final String? chatId;

  const ImageDisplay({super.key, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // chatId がある場合はそのチャットのジョブを、ない場合は最新ジョブを監視
    if (chatId != null) {
      return _buildWithChatJobs(ref, chatId!);
    } else {
      return _buildWithLatestJob(ref);
    }
  }

  Widget _buildWithChatJobs(WidgetRef ref, String chatId) {
    final jobsAsync = ref.watch(imageJobsProvider(chatId));

    return jobsAsync.when(
      data: (jobs) {
        if (jobs.isEmpty) {
          return _buildEmptyState();
        }
        // 最新のジョブを表示
        return _buildJobDisplay(jobs.first);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(error),
    );
  }

  Widget _buildWithLatestJob(WidgetRef ref) {
    final jobAsync = ref.watch(latestImageJobProvider);

    return jobAsync.when(
      data: (job) {
        if (job == null) {
          return _buildEmptyState();
        }
        return _buildJobDisplay(job);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(error),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '画像がまだありません',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Gemini に絵を描いてもらいましょう',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'エラー: $error',
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJobDisplay(ImageJob job) {
    final status = job.status;
    final imageUrl = job.imageUrl;
    final prompt = job.prompt;
    final error = job.error;

    // 処理中の表示
    if (status == 'pending' || status == 'processing') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('画像を生成中: "$prompt"...'),
            const SizedBox(height: 8),
            Text(
              status == 'pending' ? '準備中...' : '処理中...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // 完了時の表示
    if (status == 'completed' && imageUrl != null) {
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'プロンプト: "$prompt"',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    // 失敗時の表示
    if (status == 'failed') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text('画像生成に失敗しました'),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  error,
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
