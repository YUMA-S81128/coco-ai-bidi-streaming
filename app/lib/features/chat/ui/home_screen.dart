import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../logic/chat_provider.dart';
import 'chat_area.dart';
import 'chat_sidebar.dart';

/// ホームスクリーン。
///
/// サイドバー（チャット履歴）とメインコンテンツ（チャットエリア）を
/// 1ページで表示する Gemini 風のレイアウト。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    // ページアクセス時にWebSocket接続を開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).initAndConnect();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      body: Row(
        children: [
          // サイドバー（チャット履歴）
          ChatSidebar(
            isExpanded: _isSidebarExpanded,
            onToggle: _toggleSidebar,
            onChatSelected: _handleChatSelected,
            onNewChat: _handleNewChat,
            selectedChatId: chatState.chatId,
          ),

          // メインコンテンツ（チャットエリア）
          Expanded(
            child: Container(
              color: AppColors.surfaceLight,
              child: const ChatArea(),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarExpanded = !_isSidebarExpanded;
    });
  }

  void _handleChatSelected(String chatId) {
    final notifier = ref.read(chatProvider.notifier);
    notifier.switchChat(chatId);
  }

  void _handleNewChat() {
    final notifier = ref.read(chatProvider.notifier);
    notifier.startNewChat();
  }
}
