import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../services/storage_service.dart';
import '../logic/firestore_providers.dart';

/// メッセージバブルウィジェット。
///
/// ユーザーとモデルのメッセージを区別して表示し、
/// 画像生成ジョブがある場合は画像も表示する。
class MessageBubble extends ConsumerWidget {
  final Message message;
  final ImageJob? imageJob;

  const MessageBubble({super.key, required this.message, this.imageJob});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == 'user';
    final hasContent = message.content.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // メッセージバブル（コンテンツがある場合のみ表示）
          if (hasContent)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.sidebarLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser
                      ? AppColors.textOnPrimary
                      : AppColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ),

          // 画像生成セクション（存在する場合のみ）
          if (imageJob != null) _buildImageSection(context, ref, imageJob!),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, WidgetRef ref, ImageJob job) {
    final status = job.status;

    // 生成中
    if (status == 'pending' || status == 'processing') {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '画像を生成しています...',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ],
        ),
      );
    }

    // 完了 - imageUrlProvider で gs:// → https:// に変換
    if (status == 'completed' && job.imageUrl != null) {
      final imageUrlAsync = ref.watch(imageUrlProvider(job.imageUrl!));

      return Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: imageUrlAsync.when(
            data: (url) {
              if (url.isEmpty) {
                return _buildErrorContainer();
              }
              return Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    _buildErrorContainer(),
              );
            },
            loading: () => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _buildErrorContainer(),
          ),
        ),
      );
    }

    // 失敗
    if (status == 'failed') {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 16),
            const SizedBox(width: 8),
            Text(
              '画像生成に失敗しました',
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildErrorContainer() {
    return Container(
      height: 100,
      color: Colors.grey[200],
      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );
  }
}
