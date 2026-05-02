import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../data/remote/firebase/profile_services.dart';
import 'profile_info_bottomsheet.dart';

enum FollowListType { followers, following }

/// A bottom sheet that displays a list of followers or followings.
class FollowListBottomSheet extends StatelessWidget {
  final String userId;
  final FollowListType listType;

  const FollowListBottomSheet({super.key, required this.userId, required this.listType});

  @override
  Widget build(BuildContext context) {
    final String title = listType == FollowListType.followers ? 'Followers' : 'Following';
    final Stream<QuerySnapshot> stream = listType == FollowListType.followers
        ? ProfileService.getFollowersStream(userId)
        : ProfileService.getFollowingsStream(userId);

    return Column(
      children: [
        // --- Header ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        // --- List ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.pink));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text('No ${title.toLowerCase()} found.', style: const TextStyle(color: Colors.white70)),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  // Assuming the document ID is the user ID and you need to fetch their profile
                  final String followUserId = docs[index].id;
                  return _FollowListTile(followUserId: followUserId);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A stateful tile for the follow list to manage its own follow state.
class _FollowListTile extends StatelessWidget {
  final String followUserId;

  _FollowListTile({required this.followUserId});

  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final bool isCurrentUser = followUserId == currentUserId;

    // We fetch the user's profile to get their name and picture
    return FutureBuilder<DocumentSnapshot>(
      future: ProfileService.getUserProfile(followUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ListTile(
            title: Center(
              child: Text('Loading...', style: TextStyle(color: Colors.white30)),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String userName = data['displayName'] ?? 'Unknown';
        final String? userPicture = data['photoUrl'];

        return ListTile(
          onTap: () {
            showProfileInfoBottomSheet(context, userId: followUserId);
          },
          leading: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: userPicture != null && userPicture.isNotEmpty
                      ? CachedNetworkImageProvider(userPicture)
                      : null,
                  child: (userPicture == null || userPicture.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                // Overlay the Frame (40 * 1.3 = 52)
                Positioned(
                  width: 52,
                  height: 52,
                  child: IgnorePointer(child: ActiveFrameWidget(userId: followUserId, size: 52)),
                ),
              ],
            ),
          ),
          title: Text(userName, style: const TextStyle(color: Colors.white)),
          trailing: isCurrentUser
              ? null
              : StreamBuilder<bool>(
                  stream: ProfileService.isFollowing(followUserId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                    }

                    final bool isFollowing = snapshot.data ?? false;

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey.shade800 : Colors.pink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () async {
                        try {
                          if (isFollowing) {
                            await ProfileService.unfollowUser(followUserId);
                          } else {
                            await ProfileService.followUser(followUserId);
                          }
                        } catch (e) {
                          debugPrint('Error following/unfollowing user: $e');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Top-level function to show the follow list bottom sheet.
void showFollowListBottomSheet(BuildContext context, {required String userId, required FollowListType listType}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.7,
        child: FollowListBottomSheet(userId: userId, listType: listType),
      );
    },
  );
}
