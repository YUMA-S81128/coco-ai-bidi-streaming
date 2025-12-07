import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

class ChatRepository {
  WebSocketChannel? _channel;
  
  // TODO: Update with your actual project ID and region
  static const String _projectId = 'coco-ai-bidi-streaming'; 
  static const String _region = 'asia-northeast1';
  static const String _tokenEndpoint = 'http://127.0.0.1:5001/$_projectId/$_region/get_ephemeral_token';
  
  static const String _wsUrl = 'ws://127.0.0.1:8000/ws';

  Future<String> _getEphemeralToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    
    final idToken = await user.getIdToken();
    final response = await http.get(
      Uri.parse(_tokenEndpoint),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['token'];
    } else {
      throw Exception('Failed to get ephemeral token: ${response.body}');
    }
  }

  Future<void> connect() async {
    try {
      final token = await _getEphemeralToken();
      final user = FirebaseAuth.instance.currentUser;
      
      // Append token and user info to WS URL
      // In a real app, you might pass token in headers if supported, or as a query param.
      // Here we pass user_id and chat_id as query params.
      // We also pass the ephemeral token as a query param 'token' if the backend expects it,
      // or just rely on the fact that we got it (backend verification of ephemeral token is not implemented in our custom agent yet).
      
      final wsUri = Uri.parse('$_wsUrl?user_id=${user?.uid}&chat_id=default_chat&token=$token');
      
      _channel = WebSocketChannel.connect(wsUri);
      await _channel!.ready;
    } catch (e) {
      throw Exception('Failed to connect to WebSocket: $e');
    }
  }

  Stream<dynamic> get messages => _channel?.stream ?? const Stream.empty();

  void sendAudio(Uint8List data) {
    _channel?.sink.add(data);
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
