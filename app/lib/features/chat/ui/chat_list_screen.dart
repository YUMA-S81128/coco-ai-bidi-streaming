import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/firestore_providers.dart';
import 'chat_screen.dart';

/// チャット履歴一覧画面。
///
/// ユーザーの過去のチャットセッションを表示し、
/// 選択したチャットを再開したり、新規チャットを開始できる。
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('チャット履歴'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: chatsAsync.when(
        data: (chats) {
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'チャット履歴がありません',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '新しいチャットを開始しましょう',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return _ChatListTile(
                chat: chat,
                onTap: () => _navigateToChat(context, chat.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('エラーが発生しました: $error'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToChat(context, null),
        icon: const Icon(Icons.add),
        label: const Text('新規チャット'),
      ),
    );
  }

  void _navigateToChat(BuildContext context, String? chatId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
  }
}

/// チャットリストの各行。
class _ChatListTile extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const _ChatListTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('yyyy/MM/dd HH:mm');
    final displayTitle = chat.title.isNotEmpty ? chat.title : '無題のチャット';
    final displayDate = chat.updatedAt != null
        ? dateFormatter.format(chat.updatedAt!)
        : '';

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.chat)),
      title: Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(displayDate, style: TextStyle(color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
