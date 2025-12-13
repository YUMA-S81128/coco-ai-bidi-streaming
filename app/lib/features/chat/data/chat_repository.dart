import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../config/app_config.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

/// WebSocket 通信を管理するリポジトリ。
///
/// Firebase ID トークンを使用してバックエンドに認証し、
/// 音声/テキストの双方向ストリーミングを実現する。
class ChatRepository {
  WebSocketChannel? _channel;

  /// WebSocket サーバーに接続する。
  ///
  /// [chatId] に対応するチャットセッションに接続する。
  /// Firebase ID トークンをクエリパラメータとして付与し、
  /// バックエンドで認証を行う。
  ///
  /// Throws [Exception] 接続に失敗した場合。
  Future<void> connect({required String chatId}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // Firebase ID トークンを直接取得（一時トークン発行は不要）
      final token = await user.getIdToken();

      // WebSocket URI の構築
      // バックエンド URL を WebSocket プロトコルに変換
      final wsBase = AppConfig.backendUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final wsUri = Uri.parse('$wsBase/ws?token=$token&chat_id=$chatId');
      // バックエンドは token と chat_id をクエリパラメータで受け取る

      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;

      debugPrint('WebSocket connected: chatId=$chatId');
    } catch (e) {
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  /// バックエンドからのメッセージストリーム。
  Stream<dynamic> get messages => _channel?.stream ?? const Stream.empty();

  /// 接続中かどうかを返す。
  bool get isConnected => _channel != null;

  /// 音声データをバックエンドに送信する。
  void sendAudio(Uint8List data) {
    _channel?.sink.add(data);
  }

  /// テキストメッセージをバックエンドに送信する。
  void sendText(String text) {
    _channel?.sink.add(text);
  }

  /// WebSocket 接続を切断する。
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    debugPrint('WebSocket disconnected');
  }
}
