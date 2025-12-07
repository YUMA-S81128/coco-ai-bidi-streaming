import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/foundation.dart';
import '../data/chat_repository.dart';

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

enum ChatStatus { disconnected, connecting, connected, recording, error }

class ChatState {
  final ChatStatus status;
  final String? errorMessage;
  
  ChatState({this.status = ChatStatus.disconnected, this.errorMessage});
  
  ChatState copyWith({ChatStatus? status, String? errorMessage}) {
    return ChatState(
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  late final ChatRepository _repository;
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _audioSubscription;
  
  @override
  ChatState build() {
    _repository = ref.watch(chatRepositoryProvider);
    ref.onDispose(cleanup);
    return ChatState();
  }

  Future<void> init() async {
    _recorder = FlutterSoundRecorder();
    _player = FlutterSoundPlayer();
    
    try {
      await _recorder!.openRecorder();
      await _player!.openPlayer();
    } catch (e) {
      state = state.copyWith(status: ChatStatus.error, errorMessage: "Failed to init audio: $e");
    }
  }

  Future<void> connect() async {
    if (state.status == ChatStatus.connected) return;
    
    state = state.copyWith(status: ChatStatus.connecting);
    try {
      await _repository.connect();
      state = state.copyWith(status: ChatStatus.connected);
      
      // Listen for incoming audio
      _audioSubscription = _repository.messages.listen((data) {
        if (data is List<int> || data is Uint8List) {
            _playAudio(Uint8List.fromList(data as List<int>));
        } else if (data is String) {
            try {
              final json = jsonDecode(data);
              if (json['type'] == 'end_session') {
                stopRecording();
              }
            } catch (_) {
              debugPrint("Received text: $data");
            }
        }
      }, onError: (e) {
        state = state.copyWith(status: ChatStatus.error, errorMessage: "WebSocket error: $e");
      }, onDone: () {
        state = state.copyWith(status: ChatStatus.disconnected);
      });
    } catch (e) {
      state = state.copyWith(status: ChatStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> toggleSession() async {
    if (state.status == ChatStatus.recording) {
      await stopRecording();
    } else {
      // Connect if not connected
      if (state.status == ChatStatus.disconnected) {
        await connect();
      }
      
      // Start recording if connection is successful (or was already connected)
      if (state.status == ChatStatus.connected) {
        await startRecording();
      }
    }
  }

  Future<void> startRecording() async {
    if (state.status != ChatStatus.connected) return;
    
    try {
      state = state.copyWith(status: ChatStatus.recording);
      // Create a stream controller
      final recordingController = StreamController<Uint8List>();
      recordingController.stream.listen((data) {
        _repository.sendAudio(data);
      });

      // Start recording to stream
      await _recorder!.startRecorder(
        toStream: recordingController.sink,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000,
        bufferSize: 8192,
      );
    } catch (e) {
      state = state.copyWith(status: ChatStatus.error, errorMessage: "Failed to start recording: $e");
    }
  }

  Future<void> stopRecording() async {
    if (state.status != ChatStatus.recording) return;
    
    try {
      await _recorder!.stopRecorder();
      state = state.copyWith(status: ChatStatus.connected);
    } catch (e) {
      state = state.copyWith(status: ChatStatus.error, errorMessage: "Failed to stop recording: $e");
    }
  }
  
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
        debugPrint("Error playing audio: $e");
      }
  }
  
  void cleanup() {
    _audioSubscription?.cancel();
    _recorder?.closeRecorder();
    _player?.closePlayer();
    _repository.disconnect();
  }
}
