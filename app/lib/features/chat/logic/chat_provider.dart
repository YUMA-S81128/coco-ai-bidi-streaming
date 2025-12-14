import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:uuid/uuid.dart';

import '../../../models/chat_state.dart';
import '../data/chat_repository.dart';

export '../../../models/chat_state.dart';

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

/// チャットセッションを管理する Notifier。
class ChatNotifier extends Notifier<ChatState> {
  late final ChatRepository _repository;
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _audioSubscription;
  StreamController<Uint8List>? _recordingController;

  @override
  ChatState build() {
    _repository = ref.watch(chatRepositoryProvider);
    ref.onDispose(cleanup);
    return const ChatState();
  }

  /// 音声デバイスを初期化する。
  ///
  /// Web 環境ではマイク許可をリクエストし、その後レコーダーを開く。
  Future<void> init() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();

    try {
      // Web 環境でのマイク許可リクエスト
      if (kIsWeb) {
        final permitted = await _requestMicrophonePermission();
        if (!permitted) {
          state = state.copyWith(
            status: ChatStatus.error,
            errorMessage: 'マイクの使用許可が必要です',
          );
          return;
        }
      }

      await _recorder!.openRecorder();
      await _player!.openPlayer();
      debugPrint('Audio devices initialized successfully');
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Failed to init audio: $e',
      );
    }
  }

  /// Web 環境でマイク許可をリクエストする。
  Future<bool> _requestMicrophonePermission() async {
    try {
      // dart:js_interop を使用して getUserMedia を呼び出す
      // flutter_sound_web が内部で処理するため、ここでは true を返す
      // 実際の許可リクエストは startRecorder 時に発生する
      return true;
    } catch (e) {
      debugPrint('Microphone permission error: $e');
      return false;
    }
  }

  /// ページロード時に初期化とWebSocket接続を同時に開始する。
  ///
  /// ユーザーにはマイクボタン1タップで会話開始できる状態を提供する。
  /// [chatId] が指定されない場合は新規chatIdを生成する。
  Future<void> initAndConnect({String? chatId}) async {
    await init();
    final targetChatId = chatId ?? _generateUuid();
    await _connectToChat(targetChatId);
  }

  /// チャットを切り替える。
  ///
  /// 既存の接続を切断し、新しいchatIdで再接続する。
  Future<void> switchChat(String chatId) async {
    if (state.chatId == chatId) return;
    await disconnect();
    await _connectToChat(chatId);
  }

  /// 新しいチャットセッションを開始する。
  ///
  /// UUID ベースの新規 chatId を生成し接続する。
  Future<void> startNewChat() async {
    await disconnect();
    // UUID v4 形式の chatId を生成
    final chatId = _generateUuid();
    await _connectToChat(chatId);
  }

  /// 既存のチャットセッションを再開する。
  ///
  /// [chatId] 指定したチャットに接続する。
  Future<void> resumeChat(String chatId) async {
    await _connectToChat(chatId);
  }

  /// 指定した chatId に接続する。
  Future<void> _connectToChat(String chatId) async {
    if (state.status == ChatStatus.connected ||
        state.status == ChatStatus.recording) {
      return;
    }

    state = state.copyWith(status: ChatStatus.connecting, chatId: chatId);

    try {
      await _repository.connect(chatId: chatId);
      state = state.copyWith(status: ChatStatus.connected);

      // バックエンドからのメッセージを監視
      _audioSubscription = _repository.messages.listen(
        _handleMessage,
        onError: (e) {
          debugPrint('WebSocket error received: $e');
          state = state.copyWith(
            status: ChatStatus.error,
            errorMessage: 'WebSocket error: $e',
          );
        },
        onDone: () {
          debugPrint('WebSocket stream closed (onDone)');
          // 録音中に接続が切れた場合は録音を停止
          if (state.status == ChatStatus.recording) {
            stopRecording();
          }
          state = state.copyWith(status: ChatStatus.disconnected);
        },
      );
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// バックエンドからのメッセージを処理する。
  void _handleMessage(dynamic data) {
    if (data is List<int> || data is Uint8List) {
      // バイナリデータは音声として再生
      _playAudio(Uint8List.fromList(data as List<int>));
    } else if (data is String) {
      // JSON メッセージをパース
      try {
        final json = jsonDecode(data);
        // セッション終了シグナル
        if (json['type'] == 'end_session') {
          stopRecording();
        }
        // 他のイベント（音声データ含む）を処理
        _handleJsonEvent(json);
      } catch (_) {
        debugPrint('Received text: $data');
      }
    }
  }

  /// JSON イベントを処理する。
  void _handleJsonEvent(Map<String, dynamic> json) {
    // audio フィールドがある場合は再生
    // ADK の LiveEvent からの音声データを想定
    final audioData = json['audio'];
    if (audioData != null && audioData is Map) {
      final data = audioData['data'];
      if (data != null && data is String) {
        try {
          final bytes = base64Decode(data);
          _playAudio(bytes);
        } catch (e) {
          debugPrint('Failed to decode audio: $e');
        }
      }
    }
  }

  /// 録音の開始/停止を切り替える。
  Future<void> toggleSession() async {
    if (state.status == ChatStatus.recording) {
      await stopRecording();
    } else {
      // 未接続の場合は新規チャットを開始
      if (state.status == ChatStatus.disconnected) {
        await startNewChat();
      }

      // 接続成功後に録音開始
      if (state.status == ChatStatus.connected) {
        await startRecording();
      }
    }
  }

  /// 録音を開始する。
  Future<void> startRecording() async {
    if (state.status != ChatStatus.connected) return;

    try {
      state = state.copyWith(status: ChatStatus.recording);

      // 録音ストリームの作成
      _recordingController = StreamController<Uint8List>();
      _recordingController!.stream.listen((data) {
        _repository.sendAudio(data);
      });

      // 録音開始
      await _recorder!.startRecorder(
        toStream: _recordingController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
      );
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  /// 録音を停止する。
  Future<void> stopRecording() async {
    if (state.status != ChatStatus.recording) return;

    try {
      await _recorder!.stopRecorder();
      await _recordingController?.close();
      _recordingController = null;
      state = state.copyWith(status: ChatStatus.connected);
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Failed to stop recording: $e',
      );
    }
  }

  /// 音声データを再生する。
  Future<void> _playAudio(Uint8List data) async {
    try {
      if (_player!.isStopped) {
        await _player!.startPlayerFromStream(
          codec: Codec.pcm16,
          numChannels: 1,
          sampleRate: 24000,
          interleaved: false,
          bufferSize: 8192,
        );
      }
      await _player!.feedUint8FromStream(data);
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// セッションを切断し、マイクを解放する。
  Future<void> disconnect() async {
    // 録音中の場合は停止
    if (state.status == ChatStatus.recording) {
      await stopRecording();
    }

    // レコーダーを閉じてマイクを完全に解放（ブラウザのインジケーターも消える）
    await _recorder?.closeRecorder();
    _recorder = null;

    // WebSocket切断
    _repository.disconnect();
    state = state.copyWith(status: ChatStatus.disconnected, chatId: null);
  }

  /// リソースをクリーンアップする。
  void cleanup() {
    _audioSubscription?.cancel();
    _recordingController?.close();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    _repository.disconnect();
  }

  /// UUID v4 形式の文字列を生成する。
  String _generateUuid() {
    return const Uuid().v4();
  }
}
