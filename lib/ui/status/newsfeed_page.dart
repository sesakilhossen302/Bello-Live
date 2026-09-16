import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/remote/firebase/social_media_service.dart';
import '../../data/remote/firebase/media_services.dart'; // Make sure this path matches your project
import '../../navigation/routes.dart';
import 'post_card.dart';
import '../../theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

class NewsfeedPage extends StatefulWidget {
  const NewsfeedPage({super.key});

  @override
  _NewsfeedPageState createState() => _NewsfeedPageState();
}

class _NewsfeedPageState extends State<NewsfeedPage> with TickerProviderStateMixin {
  int selectedTabIndex = 0;
  final List<String> _tabTypes = ['hot', 'new', 'followed'];

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  List<Post> _posts = [];
  DocumentSnapshot? _lastDocument;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final int _pageSize = 10;

  // --- NEW MEDIA STATE VARIABLES ---
  File? _selectedMedia;
  PostMediaType _selectedMediaType = PostMediaType.text;
  bool _isUploadingPost = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPosts();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialPosts() async {
    setState(() => _isLoadingInitial = true);

    final result = await SocialMediaService.fetchFeedPage(limit: _pageSize, tabType: _tabTypes[selectedTabIndex]);

    if (mounted) {
      setState(() {
        _posts = result['posts'];
        _lastDocument = result['lastDocument'];
        _hasMore = _posts.length == _pageSize;
        _isLoadingInitial = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final result = await SocialMediaService.fetchFeedPage(
      limit: _pageSize,
      lastDocument: _lastDocument,
      tabType: _tabTypes[selectedTabIndex],
    );

    final List<Post> newPosts = result['posts'];

    if (mounted) {
      setState(() {
        _posts.addAll(newPosts);
        if (result['lastDocument'] != null) {
          _lastDocument = result['lastDocument'];
        }
        _hasMore = newPosts.length == _pageSize;
        _isLoadingMore = false;
      });
    }
  }

  // --- MEDIA PICKING HANDLERS ---
  Future<void> _handleImagePick(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        setState(() {
          _selectedMedia = File(image.path);
          _selectedMediaType = PostMediaType.image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleVideoPick() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 15),
      );
      if (video != null) {
        setState(() {
          _selectedMedia = File(video.path);
          _selectedMediaType = PostMediaType.video;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: Text(AppLocalizations.of(context).galleryPhoto, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: Text(AppLocalizations.of(context).camera, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purple),
                title: Text(AppLocalizations.of(context).videoLimit, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleVideoPick();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UPDATED POST CREATION HANDLER ---
  Future<void> _handleCreatePost() async {
    final text = _postController.text.trim();

    // Don't allow completely empty posts
    if (text.isEmpty && _selectedMedia == null) return;

    setState(() => _isUploadingPost = true);
    FocusScope.of(context).unfocus();

    String? mediaUrl;
    String? thumbnailUrl;

    try {
      // 1. Upload Media if selected
      if (_selectedMedia != null) {
        if (_selectedMediaType == PostMediaType.image) {
          mediaUrl = await MediaService.compressAndUploadImage(_selectedMedia!);
        } else if (_selectedMediaType == PostMediaType.video) {
          final videoData = await MediaService.compressAndUploadVideo(_selectedMedia!);
          if (videoData != null) {
            mediaUrl = videoData['url'];
            thumbnailUrl = videoData['thumbnailUrl'];
          }
        }

        // If media upload failed, stop the post creation
        if (mediaUrl == null) {
          throw Exception("Failed to upload media");
        }
      }

      // 2. Create the Post in Firestore
      await SocialMediaService.createPost(
        content: text,
        mediaUrl: mediaUrl,
        mediaType: _selectedMedia == null ? PostMediaType.text : _selectedMediaType,
        thumbnailUrl: thumbnailUrl,
      );

      // 3. Clean up UI
      _postController.clear();
      setState(() {
        _selectedMedia = null;
        _selectedMediaType = PostMediaType.text;
      });

      // 4. Refresh feed to show new post
      _loadInitialPosts();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPost = false);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091433),
      appBar: _buildAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTabBar(),
          const SizedBox(height: 6),
          _buildPostInputArea(),
          const SizedBox(height: 10),
          Expanded(
            child: _isLoadingInitial
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE62563)))
                : RefreshIndicator(
                    onRefresh: _loadInitialPosts,
                    color: const Color(0xFFE62563),
                    child: _posts.isEmpty
                        ? Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 40),
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1E42),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 2),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFE62563).withValues(alpha: 0.1),
                                    ),
                                    child: const Icon(
                                      Icons.article_outlined,
                                      size: 50,
                                      color: Color(0xFFE62563),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    AppLocalizations.of(context).noPostsYet,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _posts.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(child: CircularProgressIndicator(color: Color(0xFFE62563))),
                                );
                              }
                              return PostCard(
                                post: _posts[index],
                                onPostChanged: _loadInitialPosts,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFE62563),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(CupertinoIcons.back, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(
        AppLocalizations.of(context).status,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline_rounded, size: 26, color: Colors.white),
          onPressed: () => context.push(Routes.myFeed.path),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF091433),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      child: Row(
        children: [
          _buildTabItem(AppLocalizations.of(context).hot, 0, Icons.whatshot_rounded),
          const SizedBox(width: 8),
          _buildTabItem(AppLocalizations.of(context).newTab, 1, Icons.fiber_new_rounded),
          const SizedBox(width: 8),
          _buildTabItem(AppLocalizations.of(context).followed, 2, Icons.favorite_rounded),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, int index, IconData icon) {
    bool isSelected = selectedTabIndex == index;
    const primaryColor = Color(0xFFE62563);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (selectedTabIndex == index) return;
          setState(() {
            selectedTabIndex = index;
          });
          _loadInitialPosts();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.white.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostInputArea() {
    final currentAvatar = FirebaseAuth.instance.currentUser?.photoURL ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0F1E42),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            TextField(
              controller: _postController,
              style: const TextStyle(color: Colors.white),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).whatsOnYourMind,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: currentAvatar.isNotEmpty ? NetworkImage(currentAvatar) : null,
                    child: currentAvatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
                  ),
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.collections, color: Color(0xFFE62563)),
                      onPressed: () => _handleImagePick(ImageSource.gallery),
                    ),
                    _isUploadingPost
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE62563))),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_rounded, color: Color(0xFFE62563)),
                            onPressed: _handleCreatePost,
                          ),
                  ],
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              ),
            ),

            // Media Preview Area
            if (_selectedMedia != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Stack(
                  children: [
                    // Preview
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _selectedMediaType == PostMediaType.image
                          ? Image.file(
                              _selectedMedia!,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 150,
                              width: double.infinity,
                              color: Colors.black.withValues(alpha: 0.5),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.videocam, color: Colors.white, size: 40),
                                    SizedBox(height: 8),
                                    Text('Video Selected', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                    ),

                    // Remove Media Button
                    if (!_isUploadingPost)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMedia = null;
                              _selectedMediaType = PostMediaType.text;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 20),
                          ),
                        ),
                      ),

                    // Upload Overlay
                    if (_isUploadingPost)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(AppLocalizations.of(context).uploadingMedia, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}