import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  /// Gemini Live API が期待するサンプルレート
  static const int _targetSampleRate = 16000;

  /// Web ブラウザのデフォルトサンプルレート（Windows Chrome）
  ///
  /// Web環境では FlutterSound が指定したサンプルレートを無視し、
  /// OSのデフォルト（多くの場合 48000Hz）を使用するため、
  /// リサンプリングが必要。
  ///
  /// 注意: macOS では 44100Hz の場合がある。
  /// 他の環境で使用する場合はこの値の調整が必要。
  static const int _webInputSampleRate = 48000;

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

  /// 既存のチャットセッションを再開し、録音を開始する。
  ///
  /// セッション終了後にボタン1回で会話を再開するためのメソッド。
  Future<void> resumeAndStartRecording(String chatId) async {
    // レコーダーが閉じられている場合は再初期化
    if (_recorder == null) {
      _recorder = FlutterSoundRecorder();
      await _recorder!.openRecorder();
    }
    // プレイヤーが閉じられている場合は再初期化
    if (_player == null) {
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
    }

    await _connectToChat(chatId);
    // 接続完了後、自動的に録音開始
    if (state.status == ChatStatus.connected) {
      await startRecording();
    }
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
            debugPrint('Stream closed while recording, stopping...');
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
        // セッション終了シグナル - 録音停止 + マイク解放（チャットは保持）
        if (json['type'] == 'end_session') {
          endSession();
          return;
        }
        // 他のイベント（音声データ含む）を処理
        _handleJsonEvent(json);
      } catch (_) {
        // JSONパースエラーは無視
      }
    }
  }

  /// JSON イベントを処理する。
  ///
  /// ADK LiveEvent の構造から音声データを抽出して再生する。
  /// 音声データは content.parts[n].inline_data.data にbase64エンコードで格納されている。
  void _handleJsonEvent(Map<String, dynamic> json) {
    // ADK LiveEvent から音声データを抽出
    // 構造: { "content": { "parts": [{ "inline_data": { "data": "base64...", "mime_type": "..." } }] } }
    final content = json['content'];
    if (content != null && content is Map) {
      final parts = content['parts'];
      if (parts != null && parts is List) {
        for (final part in parts) {
          if (part is Map) {
            // inline_data または inlineData (camelCase) をサポート
            final inlineData = part['inline_data'] ?? part['inlineData'];
            if (inlineData != null && inlineData is Map) {
              final data = inlineData['data'];
              if (data != null && data is String) {
                try {
                  final bytes = base64Decode(data);
                  _playAudio(bytes);
                } catch (_) {
                  // base64デコードエラーは無視
                }
              }
            }
          }
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

    // レコーダーが未初期化の場合は初期化
    if (_recorder == null) {
      await init();
      if (_recorder == null) {
        state = state.copyWith(
          status: ChatStatus.error,
          errorMessage: 'マイクの初期化に失敗しました',
        );
        return;
      }
    }

    try {
      state = state.copyWith(status: ChatStatus.recording);

      // 録音ストリームの作成（リサンプリングして送信）
      _recordingController = StreamController<Uint8List>();
      _recordingController!.stream.listen((data) {
        // Web環境では常にリサンプリング（48kHz → 16kHz）
        final audioToSend = kIsWeb
            ? _resampleAudio(data, _webInputSampleRate, _targetSampleRate)
            : data;
        _repository.sendAudio(audioToSend);
      });

      // 録音開始
      await _recorder!.startRecorder(
        toStream: _recordingController!.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: _targetSampleRate,
        bufferSize: 8192,
      );
    } catch (e) {
      state = state.copyWith(
        status: ChatStatus.error,
        errorMessage: 'Failed to start recording: $e',
      );
    }
  }

  /// 音声データを目標サンプルレートにリサンプリングする。
  ///
  /// PCM16 形式（サンプルあたり2バイト）のデータを想定。
  /// 48kHz → 16kHz は 3:1 の整数比で効率的にダウンサンプリング。
  Uint8List _resampleAudio(Uint8List input, int fromRate, int toRate) {
    // PCM16 はサンプルあたり 2 バイト
    final inputSamples = input.buffer.asInt16List(
      input.offsetInBytes,
      input.lengthInBytes ~/ 2,
    );

    // リサンプリング比率を計算 (48000/16000 = 3)
    final ratio = fromRate / toRate;
    final outputLength = (inputSamples.length / ratio).floor();

    // 出力バッファを作成
    final outputSamples = Int16List(outputLength);

    // 単純な間引きでダウンサンプリング
    for (int i = 0; i < outputLength; i++) {
      final srcIndex = (i * ratio).floor();
      if (srcIndex < inputSamples.length) {
        outputSamples[i] = inputSamples[srcIndex];
      }
    }

    return Uint8List.view(outputSamples.buffer);
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
          interleaved: true,
          bufferSize: 8192,
        );
      }
      await _player!.feedUint8FromStream(data);
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  /// セッションを終了し、マイクを解放する。
  ///
  /// [disconnect] とは異なり、chatId を保持してチャット内容を表示し続ける。
  /// バックエンドからの end_session イベント受信時に使用。
  /// プレイヤーは再開時に必要なので閉じない。
  Future<void> endSession() async {
    // 録音中の場合は停止
    if (state.status == ChatStatus.recording) {
      await stopRecording();
    }

    // レコーダーのみ閉じてマイクを解放（ブラウザのインジケーターが消える）
    // プレイヤーは保持（再開時に音声再生に必要）
    await _recorder?.closeRecorder();
    _recorder = null;

    // WebSocket切断
    _repository.disconnect();

    // chatId は保持してチャット内容を表示し続ける
    state = state.copyWith(status: ChatStatus.disconnected);
  }

  /// セッションを切断し、マイクを解放する。
  ///
  /// chatId をクリアして初期画面に戻る。
  /// ユーザーが他のチャットに切り替える時に使用。
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
