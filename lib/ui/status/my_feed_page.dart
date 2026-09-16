import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/remote/firebase/social_media_service.dart';
import '../../theme/app_theme.dart';
import 'post_card.dart'; // Import the new shared widget

class MyFeedPage extends StatefulWidget {
  const MyFeedPage({super.key});

  @override
  _MyFeedPageState createState() => _MyFeedPageState();
}

class _MyFeedPageState extends State<MyFeedPage> {
  List<Post> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyPosts();
  }

  Future<void> _loadMyPosts() async {
    setState(() => _isLoading = true);
    final result = await SocialMediaService.fetchFeedPage(limit: 50, tabType: 'my_feed');
    setState(() {
      _posts = result['posts'];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const GlobalAppBackground(),
          SafeArea(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAppBar(),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                    : _posts.isEmpty
                    ? const Center(
                  child: Text("You haven't posted anything yet.", style: TextStyle(color: Colors.white54)),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return PostCard(
                      post: _posts[index],
                      onPostChanged: _loadMyPosts, // Refresh list if deleted/edited
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 8),
          const Text(
            'My Feed',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}