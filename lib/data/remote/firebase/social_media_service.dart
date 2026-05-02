import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PostMediaType { text, image, video }

class Post {
  final String id;
  final String authorId;
  String authorName;
  String authorAvatar;
  final String content;
  final String? mediaUrl;
  final PostMediaType mediaType;
  final String? thumbnailUrl;
  final DateTime createdAt;

  int reactionCount;
  int commentCount;
  int shareCount;
  final bool isShare;
  final String? originalPostId;

  bool isLikedByMe;
  Post? originalPost;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    this.mediaUrl,
    this.mediaType = PostMediaType.text,
    this.thumbnailUrl,
    required this.createdAt,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.isShare = false,
    this.originalPostId,
    this.isLikedByMe = false,
    this.originalPost,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorAvatar: data['authorAvatar'] ?? '',
      content: data['content'] ?? '',
      mediaUrl: data['mediaUrl'],
      mediaType: PostMediaType.values.firstWhere((e) => e.name == data['mediaType'], orElse: () => PostMediaType.text),
      thumbnailUrl: data['thumbnailUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reactionCount: data['reactionCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      shareCount: data['shareCount'] ?? 0,
      isShare: data['isShare'] ?? false,
      originalPostId: data['originalPostId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'content': content,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'reactionCount': reactionCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'isShare': isShare,
      'originalPostId': originalPostId,
    };
  }
}

class Comment {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String text;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.text,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown User',
      authorAvatar: data['authorAvatar'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class SocialMediaService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<Map<String, dynamic>> fetchFeedPage({
    required int limit,
    DocumentSnapshot? lastDocument,
    required String tabType,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return {'posts': <Post>[], 'lastDocument': null};

    try {
      Query query = _db.collection('posts');

      if (tabType == 'new') {
        query = query.orderBy('createdAt', descending: true);
      } else if (tabType == 'hot') {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .orderBy('createdAt', descending: true)
            .orderBy('reactionCount', descending: true);
      } else if (tabType == 'my_feed') {
        query = query.where('authorId', isEqualTo: currentUserId).orderBy('createdAt', descending: true);
      } else if (tabType == 'followed') {
        final followingSnapshot = await _db.collection('users').doc(currentUserId).collection('following').get();
        List<String> followingIds = followingSnapshot.docs.map((e) => e.id).toList();
        if (followingIds.isEmpty) return {'posts': <Post>[], 'lastDocument': null};

        if (followingIds.length > 30) followingIds = followingIds.sublist(0, 30);
        query = query.where('authorId', whereIn: followingIds).orderBy('createdAt', descending: true);
      }

      query = query.limit(limit);
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      List<Post> posts = snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();

      if (posts.isEmpty) return {'posts': posts, 'lastDocument': null};

      Set<String> uniqueAuthorIds = posts.map((p) => p.authorId).toSet();

      // NEW: Collect original post IDs to fetch them
      Set<String> originalPostIds = posts
          .where((p) => p.isShare && p.originalPostId != null)
          .map((p) => p.originalPostId!)
          .toSet();

      Map<String, Post> fetchedOriginalPosts = {};

      // NEW: Fetch original posts
      if (originalPostIds.isNotEmpty) {
        await Future.wait(originalPostIds.map((id) async {
          final doc = await _db.collection('posts').doc(id).get();
          if (doc.exists) {
            fetchedOriginalPosts[id] = Post.fromFirestore(doc);
            uniqueAuthorIds.add(fetchedOriginalPosts[id]!.authorId); // Need author data for the embedded post too
          }
        }));
      }

      Map<String, Map<String, dynamic>> freshAuthorData = {};
      await Future.wait(uniqueAuthorIds.map((authorId) async {
        final userDoc = await _db.collection('users').doc(authorId).get();
        if (userDoc.exists) {
          freshAuthorData[authorId] = userDoc.data() as Map<String, dynamic>;
        }
      }));

      for (var post in posts) {
        // Inject fresh author data for main post
        if (freshAuthorData.containsKey(post.authorId)) {
          final authorData = freshAuthorData[post.authorId]!;
          post.authorName = authorData['displayName'] ?? post.authorName;
          post.authorAvatar = authorData['photoUrl'] ?? post.authorAvatar;
        }

        // NEW: Inject embedded original post and its fresh author data
        if (post.isShare && post.originalPostId != null && fetchedOriginalPosts.containsKey(post.originalPostId)) {
          Post origPost = fetchedOriginalPosts[post.originalPostId]!;
          if (freshAuthorData.containsKey(origPost.authorId)) {
            final origAuthorData = freshAuthorData[origPost.authorId]!;
            origPost.authorName = origAuthorData['displayName'] ?? origPost.authorName;
            origPost.authorAvatar = origAuthorData['photoUrl'] ?? origPost.authorAvatar;
          }
          post.originalPost = origPost;
        }

        final likeDoc = await _db.collection('posts').doc(post.id).collection('reactions').doc(currentUserId).get();
        post.isLikedByMe = likeDoc.exists;
      }

      return {'posts': posts, 'lastDocument': snapshot.docs.last};
    } catch (e) {
      debugPrint("Error fetching feed: $e");
      return {'posts': <Post>[], 'lastDocument': null};
    }
  }

  static Future<void> createPost({
    required String content,
    String? mediaUrl,
    PostMediaType mediaType = PostMediaType.text,
    String? thumbnailUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    final post = Post(
      id: '',
      authorId: user.uid,
      authorName: userData['displayName'] ?? 'User',
      authorAvatar: userData['photoUrl'] ?? '',
      content: content,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      thumbnailUrl: thumbnailUrl,
      createdAt: DateTime.now(),
    );

    await _db.collection('posts').add(post.toMap());
  }

  // UPDATED: Now supports modifying media
  static Future<void> updatePost(
      String postId,
      String newContent, {
        bool removeMedia = false,
        String? newMediaUrl,
        PostMediaType? newMediaType,
        String? newThumbnailUrl,
      }) async {
    final Map<String, dynamic> updates = {'content': newContent};

    if (removeMedia) {
      updates['mediaUrl'] = null;
      updates['mediaType'] = PostMediaType.text.name;
      updates['thumbnailUrl'] = null;
    } else if (newMediaUrl != null) {
      updates['mediaUrl'] = newMediaUrl;
      updates['mediaType'] = newMediaType?.name ?? PostMediaType.image.name;
      updates['thumbnailUrl'] = newThumbnailUrl;
    }

    await _db.collection('posts').doc(postId).update(updates);
  }

  static Future<void> deletePost(String postId) async {
    await _db.collection('posts').doc(postId).delete();
  }

  static Future<bool> toggleReaction(String postId, bool isCurrentlyLiked) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return isCurrentlyLiked;

    final postRef = _db.collection('posts').doc(postId);
    final reactionRef = postRef.collection('reactions').doc(uid);

    try {
      await _db.runTransaction((transaction) async {
        final reactionDoc = await transaction.get(reactionRef);

        if (reactionDoc.exists) {
          transaction.delete(reactionRef);
          transaction.update(postRef, {'reactionCount': FieldValue.increment(-1)});
        } else {
          transaction.set(reactionRef, {'timestamp': FieldValue.serverTimestamp()});
          transaction.update(postRef, {'reactionCount': FieldValue.increment(1)});
        }
      });
      return !isCurrentlyLiked;
    } catch (e) {
      debugPrint("Error toggling reaction: $e");
      return isCurrentlyLiked;
    }
  }

  static Future<void> addComment(String postId, String text) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    final commentRef = _db.collection('posts').doc(postId).collection('comments').doc();
    final postRef = _db.collection('posts').doc(postId);

    final commentData = {
      'authorId': user.uid,
      'authorName': userData['displayName'] ?? 'User',
      'authorAvatar': userData['photoUrl'] ?? '',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(commentRef, commentData);
    batch.update(postRef, {'commentCount': FieldValue.increment(1)});
    await batch.commit();
  }

  static Stream<List<Comment>> getCommentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }

  static Future<void> sharePost(Post originalPost) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    final shareRef = _db.collection('posts').doc();

    // Fix: If sharing a shared post, point to the root original post.
    final rootOriginalId = originalPost.isShare && originalPost.originalPostId != null
        ? originalPost.originalPostId!
        : originalPost.id;

    final originalRef = _db.collection('posts').doc(rootOriginalId);

    final newPostData = {
      'authorId': user.uid,
      'authorName': userData['displayName'] ?? 'User',
      'authorAvatar': userData['photoUrl'] ?? '',
      'content': 'Shared a post',
      'isShare': true,
      'originalPostId': rootOriginalId,
      'createdAt': FieldValue.serverTimestamp(),
      'reactionCount': 0,
      'commentCount': 0,
      'shareCount': 0,
    };

    final batch = _db.batch();
    batch.set(shareRef, newPostData);
    batch.update(originalRef, {'shareCount': FieldValue.increment(1)});
    await batch.commit();
  }
}
