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
                title: const Text('Gallery Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handleImagePick(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library, color: Colors.purple),
                title: const Text('Video (max 15s)', style: TextStyle(color: Colors.white)),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF000000), Color(0xFF1a0a0a), Color(0xFF2d1b2b), Color(0xFF4a2c4a), Color(0xFFff6b9d)],
            stops: [0.0, 0.3, 0.6, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(),
              _buildTabBar(),
              const SizedBox(height: 10),

              // New Input Area wrapped in a Container to manage layout
              _buildPostInputArea(),

              const SizedBox(height: 10),
              Expanded(
                child: _isLoadingInitial
                    ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                    : RefreshIndicator(
                  onRefresh: _loadInitialPosts,
                  color: Colors.pink,
                  child: _posts.isEmpty
                      ? const Center(
                    child: Text("No posts yet. Say Hi!", style: TextStyle(color: Colors.white54)),
                  )
                      : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator(color: Colors.pink)),
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
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Text(
            'Status',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 28, color: Colors.pink),
            onPressed: () => context.push(Routes.myFeed.path),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              _buildTabItem('Hot', 0, Icons.whatshot),
              _buildTabItem('New', 1, Icons.fiber_new),
              _buildTabItem('Followed', 2, Icons.favorite),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(String title, int index, IconData icon) {
    bool isSelected = selectedTabIndex == index;
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
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: isSelected ? LinearGradient(colors: [Colors.pink.shade300, Colors.pink.shade600]) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: Colors.pink.withValues(alpha: 0.3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              children: [
                // Text Input and Buttons
                TextField(
                  controller: _postController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null, // Allows expanding if text gets long
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundImage: currentAvatar.isNotEmpty ? NetworkImage(currentAvatar) : null,
                        child: currentAvatar.isEmpty ? const Icon(Icons.person, size: 20) : null,
                      ),
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Attachment Button
                        IconButton(
                          icon: const Icon(Icons.photo_library_outlined, color: Colors.white70),
                          onPressed: _isUploadingPost ? null : _showMediaOptions,
                        ),
                        // Send Button
                        _isUploadingPost
                            ? const Padding(
                          padding: EdgeInsets.only(right: 16.0, left: 8.0),
                          child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.pink)
                          ),
                        )
                            : IconButton(
                          icon: Icon(Icons.send, color: Colors.pink.shade300),
                          onPressed: _handleCreatePost,
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                              child: const Center(
                                child: Text('Uploading Media...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}