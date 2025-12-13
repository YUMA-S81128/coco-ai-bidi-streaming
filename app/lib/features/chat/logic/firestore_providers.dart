import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// チャットセッションのモデル。
class Chat {
  final String id;
  final String userId;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Chat({
    required this.id,
    required this.userId,
    required this.title,
    this.createdAt,
    this.updatedAt,
  });

  factory Chat.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Chat(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 画像生成ジョブのモデル。
class ImageJob {
  final String id;
  final String userId;
  final String chatId;
  final String? messageId;
  final String prompt;
  final String status;
  final String? imageUrl;
  final String? error;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ImageJob({
    required this.id,
    required this.userId,
    required this.chatId,
    this.messageId,
    required this.prompt,
    required this.status,
    this.imageUrl,
    this.error,
    this.createdAt,
    this.updatedAt,
  });

  factory ImageJob.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ImageJob(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      chatId: data['chatId'] as String? ?? '',
      messageId: data['messageId'] as String?,
      prompt: data['prompt'] as String? ?? '',
      status: data['status'] as String? ?? 'pending',
      imageUrl: data['imageUrl'] as String?,
      error: data['error'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// 現在の認証ユーザー ID を提供するプロバイダー。
final currentUserIdProvider = Provider<String?>((ref) {
  return FirebaseAuth.instance.currentUser?.uid;
});

/// ユーザーのチャット一覧を監視するプロバイダー。
///
/// 更新日時の降順でソートされたチャット一覧を返す。
final chatsProvider = StreamProvider<List<Chat>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('userId', isEqualTo: userId)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(Chat.fromDocument).toList());
});

/// 特定チャットの画像ジョブを監視するプロバイダー。
///
/// [chatId] に関連する画像ジョブを作成日時の降順で返す。
final imageJobsProvider = StreamProvider.family<List<ImageJob>, String>((
  ref,
  chatId,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('image_jobs')
      .where('userId', isEqualTo: userId)
      .where('chatId', isEqualTo: chatId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ImageJob.fromDocument).toList());
});

/// ユーザーの最新画像ジョブを監視するプロバイダー。
///
/// チャットに関係なく、ユーザーの最新の画像ジョブ 1 件を返す。
final latestImageJobProvider = StreamProvider<ImageJob?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('image_jobs')
      .where('userId', isEqualTo: userId)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return ImageJob.fromDocument(snapshot.docs.first);
      });
});
