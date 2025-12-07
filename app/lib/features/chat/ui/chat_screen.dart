import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../logic/chat_provider.dart';
import 'image_display.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize audio and connect on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Live'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: const EdgeInsets.all(8.0),
            color: _getStatusColor(chatState.status),
            width: double.infinity,
            child: Text(
              'Status: ${chatState.status.name} ${chatState.errorMessage ?? ""}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          
          // Image Display Area
          const Expanded(
            child: ImageDisplay(),
          ),
          
          // Controls
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                InkWell(
                  onTap: () => ref.read(chatProvider.notifier).toggleSession(),
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chatState.status == ChatStatus.recording ? Colors.red : Colors.blue,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Icon(
                      chatState.status == ChatStatus.recording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(chatState.status == ChatStatus.recording ? "Tap to Stop" : "Tap to Start"),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Color _getStatusColor(ChatStatus status) {
    switch (status) {
      case ChatStatus.disconnected: return Colors.grey;
      case ChatStatus.connecting: return Colors.orange;
      case ChatStatus.connected: return Colors.green;
      case ChatStatus.recording: return Colors.red;
      case ChatStatus.error: return Colors.redAccent;
    }
  }
}
