import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/chat.dart';
import '../../../models/image_job.dart';

export '../../../models/chat.dart';
export '../../../models/image_job.dart';

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
