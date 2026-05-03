import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/localization/app_localizations.dart';

import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../data/remote/firebase/profile_services.dart';
import '../../../theme/app_theme.dart';

// ADDED: Import the profile info bottom sheet (Update this path if necessary for your folder structure)
import '../live_streaming/bottomsheets/profile_info_bottomsheet.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  List<UserSearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel previous timer
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Start new timer with 400ms delay
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    // Trim the query
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final List<UserSearchResult> results = [];
      final Set<String> seenIds = {};

      // First, try exact displayId match (trimmed)
      final idQuery = await _firestore.collection('users').where('displayId', isEqualTo: trimmedQuery).limit(1).get();

      // If exact ID match found, return only that user
      if (idQuery.docs.isNotEmpty) {
        final doc = idQuery.docs.first;
        if (doc.id != _currentUserId) {
          final data = doc.data();
          final isFollowing = await _checkIfFollowing(doc.id);

          results.add(
            UserSearchResult(
              userId: doc.id,
              displayName: data['displayName'] ?? 'Unknown',
              displayId: data['displayId'] ?? '',
              photoUrl: data['photoUrl'],
              bio: data['bio'] ?? '',
              isFollowing: isFollowing,
            ),
          );

          if (mounted) {
            setState(() {
              _searchResults = results;
              _isSearching = false;
            });
          }
          return; // Return early with only the exact ID match
        }
      }

      // If no exact ID match, search by name (partial, case-insensitive, trimmed)
      final lowerQuery = trimmedQuery.toLowerCase();

      final usersSnapshot = await _firestore.collection('users').limit(500).get();

      for (final doc in usersSnapshot.docs) {
        if (doc.id == _currentUserId) continue;

        final data = doc.data();
        // Trim and convert to lowercase for comparison
        final displayName = (data['displayName'] ?? '').toString().trim().toLowerCase();

        // Check if query matches any part of displayName (case-insensitive, trimmed)
        if (displayName.contains(lowerQuery) && !seenIds.contains(doc.id)) {
          final isFollowing = await _checkIfFollowing(doc.id);

          results.add(
            UserSearchResult(
              userId: doc.id,
              displayName: data['displayName'] ?? 'Unknown',
              displayId: data['displayId'] ?? '',
              photoUrl: data['photoUrl'],
              bio: data['bio'] ?? '',
              isFollowing: isFollowing,
            ),
          );
          seenIds.add(doc.id);
        }

        // Limit results to 50 for better performance
        if (results.length >= 50) break;
      }

      // Sort results alphabetically by name
      results.sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Search error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<bool> _checkIfFollowing(String userId) async {
    if (_currentUserId == null) return false;
    try {
      final doc = await _firestore.collection('users').doc(_currentUserId).collection('following').doc(userId).get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  Future<void> _toggleFollow(int index) async {
    if (_currentUserId == null) return;

    final user = _searchResults[index];
    final newFollowState = !user.isFollowing;

    // Optimistic update
    setState(() {
      _searchResults[index] = user.copyWith(isFollowing: newFollowState);
    });

    try {
      if (newFollowState) {
        await ProfileService.followUser(user.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Following ${user.displayName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        await ProfileService.unfollowUser(user.userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unfollowed ${user.displayName}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _searchResults[index] = user.copyWith(isFollowing: !newFollowState);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient), // Fix applied here
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(child: _buildSearchResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Text(
            AppLocalizations.of(context).searchUsers,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_searchResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '${_searchResults.length} ${AppLocalizations.of(context).foundSuffix}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.3), width: 1),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context).searchPlaceholder,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: const Icon(Icons.search, color: Colors.purple),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchResults = [];
                _hasSearched = false;
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching && _searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.pink),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).searching, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 80, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context).noUsersFound, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).tryDifferentSearch, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && !_hasSearched) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildUserCard(_searchResults[index], index);
      },
    );
  }

  Widget _buildUserCard(UserSearchResult user, int index) {
    // ADDED: GestureDetector to capture taps on the entire card
    return GestureDetector(
      onTap: () {
        // Dismiss the keyboard if it's open
        FocusScope.of(context).unfocus();

        // Show the bottom sheet
        showProfileInfoBottomSheet(context, userId: user.userId);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            // Profile Picture
            SizedBox(
              width: 56, // 28 * 2
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey.shade700,
                    backgroundImage: user.photoUrl != null && user.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(user.photoUrl!)
                        : null,
                    child: user.photoUrl == null || user.photoUrl!.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 28)
                        : null,
                  ),
                  // Overlay the Frame (56 * 1.3 = 72.8)
                  Positioned(
                    width: 72.8,
                    height: 72.8,
                    child: IgnorePointer(
                      child: ActiveFrameWidget(userId: user.userId, size: 72.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('ID: ${user.displayId}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                  if (user.bio.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.bio,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Follow/Unfollow Button
            _buildFollowButton(user, index),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton(UserSearchResult user, int index) {
    return ElevatedButton(
      onPressed: () => _toggleFollow(index),
      style: ElevatedButton.styleFrom(
        backgroundColor: user.isFollowing ? Colors.grey.shade700 : AppColors.pinkLight,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: Text(
        user.isFollowing ? AppLocalizations.of(context).unfollow : AppLocalizations.of(context).follow,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// Model class for search results
class UserSearchResult {
  final String userId;
  final String displayName;
  final String displayId;
  final String? photoUrl;
  final String bio;
  final bool isFollowing;

  UserSearchResult({
    required this.userId,
    required this.displayName,
    required this.displayId,
    this.photoUrl,
    required this.bio,
    required this.isFollowing,
  });

  UserSearchResult copyWith({
    String? userId,
    String? displayName,
    String? displayId,
    String? photoUrl,
    String? bio,
    bool? isFollowing,
  }) {
    return UserSearchResult(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      displayId: displayId ?? this.displayId,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}