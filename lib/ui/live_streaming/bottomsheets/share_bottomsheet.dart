import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart'; // REQUIRED: Add 'share_plus' to pubspec.yaml
import '../../../data/remote/firebase/inbox_services.dart';

// Helper Enum to ensure consistency
enum RoomType { audio, video, live }

class ShareUser {
  final String id;
  final String name;
  final String? photoUrl;
  final String relationship;

  ShareUser({
    required this.id,
    required this.name,
    this.photoUrl,
    required this.relationship,
  });
}

class ShareBottomSheet extends StatefulWidget {
  final String roomId;
  final String hostName;
  final RoomType roomType;

  const ShareBottomSheet({
    super.key,
    required this.roomId,
    required this.hostName,
    required this.roomType,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ShareUser> _allUsers = [];
  List<ShareUser> _filteredUsers = [];
  final Set<String> _selectedUserIds = {};

  bool _isLoading = true;
  String _filterMode = 'All';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    try {
      final followingSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      final followersSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();

      final Set<String> followingIds = followingSnap.docs
          .map((doc) => doc.id)
          .toSet();
      final Set<String> followerIds = followersSnap.docs
          .map((doc) => doc.id)
          .toSet();

      final Set<String> allIdsToFetch = {};
      allIdsToFetch.addAll(followingIds);
      allIdsToFetch.addAll(followerIds);

      if (allIdsToFetch.isEmpty) {
        if (mounted) {
          setState(() {
            _allUsers = [];
            _filteredUsers = [];
            _isLoading = false;
          });
        }
        return;
      }

      final List<DocumentSnapshot> userDocs = await Future.wait(
        allIdsToFetch.map((id) => _firestore.collection('users').doc(id).get()),
      );

      final List<ShareUser> fetchedUsers = [];

      for (var doc in userDocs) {
        if (!doc.exists) continue;

        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;

        String relationship = 'Follower';
        if (followingIds.contains(userId)) {
          relationship = 'Following';
        } else {
          relationship = 'Follower';
        }

        fetchedUsers.add(
          ShareUser(
            id: userId,
            name: data['displayName'] ?? data['name'] ?? 'Unknown',
            photoUrl: data['photoUrl'] ?? data['userPicture'] ?? data['image'],
            relationship: relationship,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allUsers = fetchedUsers;
          _filteredUsers = fetchedUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final matchesSearch = user.name.toLowerCase().contains(query);
        bool matchesDropdown = true;
        if (_filterMode == 'Marked') {
          matchesDropdown = _selectedUserIds.contains(user.id);
        } else if (_filterMode == 'Unmarked') {
          matchesDropdown = !_selectedUserIds.contains(user.id);
        }
        return matchesSearch && matchesDropdown;
      }).toList();
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
      _filterList();
    });
  }

  void _handleShare() async {
    if (_selectedUserIds.isEmpty) return;
    try {
      await InboxService.sendRoomInvite(
        receiverIds: _selectedUserIds.toList(),
        roomId: widget.roomId,
        roomHostName: widget.hostName,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent invites to ${_selectedUserIds.length} users!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // --- CHANGED LOGIC HERE: Opens Native Share Sheet ---
  void _handleExternalShare() {
    final String hostName = widget.hostName;
    final String roomId = widget.roomId;
    const String packageName = 'com.pigobdlive.app';

    final String playStoreLink =
        'https://play.google.com/store/apps/details?id=$packageName&referrer=roomId%3D$roomId';

    final String message = "$hostName\n$playStoreLink";

    // ignore: deprecated_member_use
    Share.share(message, subject: '$hostName - Pigo Live');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            "Share Board",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(color: Colors.white24, height: 1),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white54,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filterMode,
                    dropdownColor: const Color(0xFF2d1b2b),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: ['All', 'Marked', 'Unmarked'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _filterMode = newValue!;
                        _filterList();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
          child: Row(
            children: [
              Text(
                "${_selectedUserIds.length} Selected",
                style: const TextStyle(
                  color: Colors.pink,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: null, // Locked
                icon: const Icon(
                  Icons.share,
                  color: Colors.white24, // Disabled look
                  size: 26,
                ),
                tooltip: 'Share Externally (Locked)',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              // --- Internal Share Button ---
              IconButton(
                onPressed: _selectedUserIds.isEmpty ? null : _handleShare,
                icon: Icon(
                  Icons.send_rounded,
                  color: _selectedUserIds.isEmpty
                      ? Colors.grey
                      : Colors.blueAccent,
                  size: 28,
                ),
                tooltip: 'Send Invite to Selected',
                padding: EdgeInsets.zero,
                disabledColor: Colors.grey,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 24),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.pink),
                )
              : _filteredUsers.isEmpty
              ? const Center(
                  child: Text(
                    "No users found",
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final isSelected = _selectedUserIds.contains(user.id);

                    return ListTile(
                      onTap: () => _toggleSelection(user.id),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white10,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        user.relationship,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: Colors.pink,
                        checkColor: Colors.white,
                        side: const BorderSide(
                          color: Colors.white54,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) => _toggleSelection(user.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Updated Helper Function
void showShareBottomSheet(
  BuildContext context,
  String roomId,
  String hostName,
  RoomType roomType,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF2d1b2b),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.85,
      child: ShareBottomSheet(
        roomId: roomId,
        hostName: hostName,
        roomType: roomType,
      ),
    ),
  );
}
