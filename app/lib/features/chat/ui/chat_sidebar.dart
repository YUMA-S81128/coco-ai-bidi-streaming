import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/app_theme.dart';
import '../logic/firestore_providers.dart';

/// サイドバーコンポーネント。
///
/// パターンB: アイコンのみ（縮小）⇔ フル表示のトグル
class ChatSidebar extends ConsumerWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final void Function(String chatId) onChatSelected;
  final VoidCallback onNewChat;
  final String? selectedChatId;

  static const double expandedWidth = 280;
  static const double collapsedWidth = 64;

  const ChatSidebar({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.onChatSelected,
    required this.onNewChat,
    this.selectedChatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isExpanded ? expandedWidth : collapsedWidth,
      decoration: BoxDecoration(
        color: AppColors.sidebarLight,
        border: Border(
          right: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Column(
        children: [
          // ヘッダー（トグルボタン + 新規チャット）
          _buildHeader(),
          const Divider(height: 1),
          // チャット履歴リスト
          Expanded(
            child: chatsAsync.when(
              data: (chats) => _buildChatList(chats),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Icon(Icons.error, color: AppColors.error)),
            ),
          ),
          const Divider(height: 1),
          // フッター（ユーザー情報/ログアウト）
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // トグルボタン
          Align(
            alignment: isExpanded ? Alignment.centerRight : Alignment.center,
            child: IconButton(
              onPressed: onToggle,
              icon: Icon(isExpanded ? Icons.chevron_left : Icons.menu),
              tooltip: isExpanded ? 'サイドバーを閉じる' : 'サイドバーを開く',
            ),
          ),
          const SizedBox(height: 8),
          // 新規チャットボタン
          isExpanded
              ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.add),
                    label: const Text('新規チャット'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add),
                  tooltip: '新規チャット',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textOnPrimary,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<Chat> chats) {
    if (chats.isEmpty) {
      return Center(
        child: isExpanded
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text('チャット履歴なし', style: TextStyle(color: Colors.grey[600])),
                ],
              )
            : Icon(Icons.chat_bubble_outline, color: Colors.grey[400]),
      );
    }

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isSelected = chat.id == selectedChatId;

        return _ChatListItem(
          chat: chat,
          isExpanded: isExpanded,
          isSelected: isSelected,
          onTap: () => onChatSelected(chat.id),
        );
      },
    );
  }

  Widget _buildFooter() {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: isExpanded
          ? Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user?.displayName?.substring(0, 1).toUpperCase() ?? 'U',
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    user?.displayName ?? 'ユーザー',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                IconButton(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout, size: 20),
                  tooltip: 'ログアウト',
                ),
              ],
            )
          : IconButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              icon: const Icon(Icons.logout),
              tooltip: 'ログアウト',
            ),
    );
  }
}

/// チャットリストの各項目。
class _ChatListItem extends StatelessWidget {
  final Chat chat;
  final bool isExpanded;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.chat,
    required this.isExpanded,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MM/dd');
    final displayTitle = chat.title.isNotEmpty ? chat.title : '無題のチャット';
    final displayDate = chat.updatedAt != null
        ? dateFormatter.format(chat.updatedAt!)
        : '';

    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: isExpanded
              ? Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          Text(
                            displayDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Tooltip(
                  message: displayTitle,
                  child: Center(
                    child: Icon(
                      Icons.chat_bubble,
                      color: isSelected ? AppColors.primary : Colors.grey[600],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
