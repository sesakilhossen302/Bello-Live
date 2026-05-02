import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/remote/firebase/social_media_service.dart';
import '../../data/remote/firebase/media_services.dart';
import 'comment_bottom_sheet.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final VoidCallback onPostChanged;

  const PostCard({
    super.key,
    required this.post,
    required this.onPostChanged,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLikedByMe;
  late int _reactionCount;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isLikedByMe = widget.post.isLikedByMe;
    _reactionCount = widget.post.reactionCount;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _isLikedByMe = widget.post.isLikedByMe;
      _reactionCount = widget.post.reactionCount;
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLikedByMe = !_isLikedByMe;
      _isLikedByMe ? _reactionCount++ : _reactionCount--;
    });

    widget.post.isLikedByMe = _isLikedByMe;
    widget.post.reactionCount = _reactionCount;

    await SocialMediaService.toggleReaction(widget.post.id, !_isLikedByMe);
  }

  // --- UPDATED: EDIT POST DIALOG WITH MEDIA ---
  void _showEditDialog() {
    final TextEditingController editController = TextEditingController(text: widget.post.content);

    // Local state for the dialog
    File? newSelectedMedia;
    PostMediaType newMediaType = PostMediaType.text;
    bool removeExistingMedia = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {

          Future<void> pickMedia(ImageSource source, bool isVideo) async {
            try {
              final file = isVideo
                  ? await _imagePicker.pickVideo(source: source, maxDuration: const Duration(seconds: 15))
                  : await _imagePicker.pickImage(source: source, imageQuality: 85);

              if (file != null) {
                setStateDialog(() {
                  newSelectedMedia = File(file.path);
                  newMediaType = isVideo ? PostMediaType.video : PostMediaType.image;
                  removeExistingMedia = true; // Replace whatever was there
                });
              }
            } catch (e) {
              debugPrint("Error picking media: $e");
            }
          }

          return AlertDialog(
            backgroundColor: Colors.grey.shade900,
            title: const Text('Edit Post', style: TextStyle(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: editController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Media Preview / Controls
                  if (!removeExistingMedia && widget.post.mediaUrl != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(imageUrl: widget.post.mediaUrl!, height: 100, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setStateDialog(() => removeExistingMedia = true),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    )
                  else if (newSelectedMedia != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: newMediaType == PostMediaType.image
                              ? Image.file(newSelectedMedia!, height: 100, width: double.infinity, fit: BoxFit.cover)
                              : Container(height: 100, color: Colors.black54, child: const Center(child: Icon(Icons.videocam, color: Colors.white))),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setStateDialog(() => newSelectedMedia = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    )
                  else
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.blue),
                          onPressed: () => pickMedia(ImageSource.gallery, false),
                        ),
                        IconButton(
                          icon: const Icon(Icons.videocam, color: Colors.purple),
                          onPressed: () => pickMedia(ImageSource.gallery, true),
                        ),
                        const Text("Attach file", style: TextStyle(color: Colors.white54, fontSize: 12))
                      ],
                    ),
                ],
              ),
            ),
            actions: [
              if (!isSaving)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
              isSaving
                  ? const Padding(padding: EdgeInsets.all(8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink)))
                  : TextButton(
                onPressed: () async {
                  setStateDialog(() => isSaving = true);
                  String? uploadedUrl;
                  String? thumbnailUrl;

                  if (newSelectedMedia != null) {
                    if (newMediaType == PostMediaType.image) {
                      uploadedUrl = await MediaService.compressAndUploadImage(newSelectedMedia!);
                    } else {
                      final videoData = await MediaService.compressAndUploadVideo(newSelectedMedia!);
                      if (videoData != null) {
                        uploadedUrl = videoData['url'];
                        thumbnailUrl = videoData['thumbnailUrl'];
                      }
                    }
                  }

                  await SocialMediaService.updatePost(
                    widget.post.id,
                    editController.text,
                    removeMedia: removeExistingMedia && newSelectedMedia == null,
                    newMediaUrl: uploadedUrl,
                    newMediaType: newMediaType,
                    newThumbnailUrl: thumbnailUrl,
                  );

                  if (mounted) Navigator.pop(context);
                  widget.onPostChanged(); // Trigger parent refresh
                },
                child: const Text('Save', style: TextStyle(color: Colors.pink)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Delete Post?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              await SocialMediaService.deletePost(widget.post.id);
              if (mounted) Navigator.pop(context);
              widget.onPostChanged(); // Trigger parent refresh
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: SHARE CONFIRMATION DIALOG ---
  void _showShareConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Share Post', style: TextStyle(color: Colors.white)),
        content: const Text('Do you want to share this post on your feed?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await SocialMediaService.sharePost(widget.post);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post Shared!')));
                widget.onPostChanged(); // Refresh feed to see the new share
              }
            },
            child: const Text('Yes, Share', style: TextStyle(color: Colors.pink)),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Helper to render media (used by both main post and embedded post)
  Widget _buildMediaContent(String? mediaUrl, PostMediaType type, String? thumbnailUrl) {
    if (mediaUrl == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: type == PostMediaType.image
            ? CachedNetworkImage(imageUrl: mediaUrl, width: double.infinity, fit: BoxFit.cover)
            : Stack(
          alignment: Alignment.center,
          children: [
            if (thumbnailUrl != null)
              CachedNetworkImage(imageUrl: thumbnailUrl, width: double.infinity, fit: BoxFit.cover)
            else
              Container(height: 200, color: Colors.black54),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle, border: Border.all(color: Colors.white)),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMyPost = currentUserId == widget.post.authorId;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.isShare)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.repeat, color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Text('Shared a post', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),

                // Header (Sharer OR Original Author if not a share)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: widget.post.authorAvatar.isNotEmpty ? NetworkImage(widget.post.authorAvatar) : null,
                      child: widget.post.authorAvatar.isEmpty ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.post.authorName,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _getTimeAgo(widget.post.createdAt),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (isMyPost)
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, color: Colors.white70),
                          padding: EdgeInsets.zero,
                          color: Colors.grey.shade800,
                          onSelected: (value) {
                            if (value == 'edit') _showEditDialog();
                            if (value == 'delete') _showDeleteDialog();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Main Content (If they added text while sharing, or regular post text)
                if (widget.post.content.isNotEmpty)
                  Text(widget.post.content, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15)),

                // Regular Post Media
                if (!widget.post.isShare)
                  _buildMediaContent(widget.post.mediaUrl, widget.post.mediaType, widget.post.thumbnailUrl),

                // --- UPDATED: EMBEDDED SHARED POST UI ---
                if (widget.post.isShare)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: widget.post.originalPost == null
                        ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('This post has been deleted or is unavailable.', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: widget.post.originalPost!.authorAvatar.isNotEmpty ? NetworkImage(widget.post.originalPost!.authorAvatar) : null,
                              child: widget.post.originalPost!.authorAvatar.isEmpty ? const Icon(Icons.person, size: 12) : null,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.post.originalPost!.authorName,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _getTimeAgo(widget.post.originalPost!.createdAt),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (widget.post.originalPost!.content.isNotEmpty)
                          Text(widget.post.originalPost!.content, style: const TextStyle(color: Colors.white70, fontSize: 14)),

                        // Original Post Media
                        _buildMediaContent(widget.post.originalPost!.mediaUrl, widget.post.originalPost!.mediaType, widget.post.originalPost!.thumbnailUrl),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Footer Interactions
                Row(
                  children: [
                    _buildInteractionButton(
                      icon: _isLikedByMe ? Icons.favorite : Icons.favorite_border,
                      color: _isLikedByMe ? Colors.pink : Colors.white70,
                      count: _reactionCount,
                      onTap: _toggleLike,
                    ),
                    const SizedBox(width: 24),
                    _buildInteractionButton(
                      icon: Icons.chat_bubble_outline,
                      color: Colors.white70,
                      count: widget.post.commentCount,
                      onTap: () {
                        CommentBottomSheet.show(context, widget.post.id);
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildInteractionButton(
                      icon: Icons.share_outlined,
                      color: Colors.white70,
                      count: widget.post.shareCount,
                      onTap: _showShareConfirmation, // Calls the new confirmation dialog
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}