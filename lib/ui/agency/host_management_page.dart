import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HostManagementPage extends StatefulWidget {
  final String? agencyId;
  const HostManagementPage({super.key, this.agencyId});

  @override
  State<HostManagementPage> createState() => _HostManagementPageState();
}

class _HostManagementPageState extends State<HostManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = true;
  int _totalDiamonds = 0;
  num _userBalance = 0;

  DocumentReference<Map<String, dynamic>>? _agencyRef;
  String? _agencyId;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _agencySubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  List<Map<String, dynamic>> _hosts = [];
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToUserBalance();
    _fetchData();
  }

  @override
  void dispose() {
    _agencySubscription?.cancel();
    _userSubscription?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToUserBalance() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final raw = data['balance'] ?? data['beans'] ?? 0;
        num bal = 0;
        if (raw is num) {
          bal = raw;
        } else {
          bal = num.tryParse(raw.toString()) ?? 0;
        }
        setState(() {
          _userBalance = bal;
        });
      }
    });
  }

  String _formatBalance(num val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(2);
  }

  int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? 0);
    }
    return 0;
  }

  String _formatDuration(dynamic value) {
    final val = _parseInt(value);
    final d = val > 100000 ? Duration(milliseconds: val) : Duration(minutes: val);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${h}h ${m}m';
  }

  String _extractUserPhoto(Map<String, dynamic> data) {
    for (final key in [
      'photoUrl',
      'photo',
      'avatar',
      'profileImage',
      'image',
      'userPicture',
      'avatarUrl',
      'profilePicture',
    ]) {
      final val = data[key]?.toString().trim();
      if (val != null && val.isNotEmpty && (val.startsWith('http://') || val.startsWith('https://'))) {
        return val;
      }
    }
    return '';
  }

  Future<void> _fetchData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 0. Fetch initial user balance
      final userDocDirect = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDocDirect.exists && mounted) {
        final data = userDocDirect.data();
        final raw = data?['balance'] ?? data?['beans'] ?? 0;
        num bal = 0;
        if (raw is num) {
          bal = raw;
        } else {
          bal = num.tryParse(raw.toString()) ?? 0;
        }
        setState(() {
          _userBalance = bal;
        });
      }

      DocumentSnapshot<Map<String, dynamic>>? agencyDoc;

      // 1. Direct check if widget.agencyId was provided
      if (widget.agencyId != null && widget.agencyId!.isNotEmpty) {
        final docById = await FirebaseFirestore.instance
            .collection('agencies')
            .doc(widget.agencyId)
            .get();
        if (docById.exists) {
          agencyDoc = docById;
        }
      }

      // 2. Query agencies where ownerId == currentUser.uid
      if (agencyDoc == null) {
        final ownerQuery = await FirebaseFirestore.instance
            .collection('agencies')
            .where('ownerId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
        if (ownerQuery.docs.isNotEmpty) {
          agencyDoc = ownerQuery.docs.first;
        }
      }

      // 3. Query user profile for agencyId
      if (agencyDoc == null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        if (userDoc.exists) {
          final userAgId = userDoc.data()?['agencyId']?.toString();
          if (userAgId != null && userAgId.isNotEmpty) {
            final docById = await FirebaseFirestore.instance
                .collection('agencies')
                .doc(userAgId)
                .get();
            if (docById.exists) {
              agencyDoc = docById;
            }
          }
        }
      }

      // 4. Query agency_applications
      if (agencyDoc == null) {
        final appDoc = await FirebaseFirestore.instance
            .collection('agency_applications')
            .doc(currentUser.uid)
            .get();
        if (appDoc.exists) {
          final agId = appDoc.data()?['agencyId']?.toString();
          if (agId != null && agId.isNotEmpty) {
            final docById = await FirebaseFirestore.instance
                .collection('agencies')
                .doc(agId)
                .get();
            if (docById.exists) {
              agencyDoc = docById;
            }
          }
        } else {
          final appQuery = await FirebaseFirestore.instance
              .collection('agency_applications')
              .where('userId', isEqualTo: currentUser.uid)
              .limit(1)
              .get();
          if (appQuery.docs.isNotEmpty) {
            final agId = appQuery.docs.first.data()['agencyId']?.toString();
            if (agId != null && agId.isNotEmpty) {
              final docById = await FirebaseFirestore.instance
                  .collection('agencies')
                  .doc(agId)
                  .get();
              if (docById.exists) {
                agencyDoc = docById;
              }
            }
          }
        }
      }

      // 5. Query agencies by email
      if (agencyDoc == null && currentUser.email != null && currentUser.email!.isNotEmpty) {
        final emailQuery = await FirebaseFirestore.instance
            .collection('agencies')
            .where('email', isEqualTo: currentUser.email)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          agencyDoc = emailQuery.docs.first;
        }
      }

      // 6. Query agencies by currentUser.uid as doc ID
      if (agencyDoc == null) {
        final docById = await FirebaseFirestore.instance
            .collection('agencies')
            .doc(currentUser.uid)
            .get();
        if (docById.exists) {
          agencyDoc = docById;
        }
      }

      if (agencyDoc != null && agencyDoc.exists) {
        _agencyRef = agencyDoc.reference;
        _agencyId = agencyDoc.id;

        // Setup real-time listener if not already listening
        _agencySubscription ??= _agencyRef!.snapshots().listen((snap) {
          if (!mounted) return;
          if (snap.exists) {
            final raw = snap.data()?['hosts'] as List<dynamic>? ?? [];
            final currentHosts = raw.map((e) => e.toString()).toSet();
            final loadedHosts = _hosts.map((h) => h['applicantId'].toString()).toSet();
            if (currentHosts.length != loadedHosts.length || !currentHosts.containsAll(loadedHosts)) {
              _fetchData();
            }
          }
        });
      }

      // Extract host IDs array from agency document
      final List<String> hostIdsFromAgency = [];
      if (agencyDoc != null && agencyDoc.exists) {
        final rawHosts = agencyDoc.data()?['hosts'];
        if (rawHosts is List) {
          for (var h in rawHosts) {
            if (h != null && h.toString().trim().isNotEmpty) {
              final idStr = h.toString().trim();
              if (!hostIdsFromAgency.contains(idStr)) {
                hostIdsFromAgency.add(idStr);
              }
            }
          }
        }
      }

      // Fetch HostRequests for this agency / owner
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> approvedRequestsMap = {};
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> pendingRequestDocs = [];
      final Set<String> processedReqIds = {};

      void processReqDocs(QuerySnapshot<Map<String, dynamic>> snap) {
        for (var doc in snap.docs) {
          if (!processedReqIds.add(doc.id)) continue;
          final data = doc.data();
          final applicantId = data['applicantId']?.toString();
          final status = data['status']?.toString();
          if (applicantId == null) continue;

          if (status == 'approved') {
            approvedRequestsMap[applicantId] = doc;
          } else if (status == 'pending') {
            pendingRequestDocs.add(doc);
          }
        }
      }

      final reqsByOwner = await FirebaseFirestore.instance
          .collection('HostRequests')
          .where('ownerId', isEqualTo: currentUser.uid)
          .get();
      processReqDocs(reqsByOwner);

      if (_agencyId != null && _agencyId!.isNotEmpty) {
        final reqsByAgency = await FirebaseFirestore.instance
            .collection('HostRequests')
            .where('agencyId', isEqualTo: _agencyId)
            .get();
        processReqDocs(reqsByAgency);
      }

      // If there are approved HostRequests not yet in the agency hosts array, include them
      for (var applicantId in approvedRequestsMap.keys) {
        if (!hostIdsFromAgency.contains(applicantId)) {
          hostIdsFromAgency.add(applicantId);
          if (_agencyRef != null) {
            _agencyRef!.update({
              'hosts': FieldValue.arrayUnion([applicantId])
            }).catchError((_) {});
          }
        }
      }

      List<Map<String, dynamic>> fetchedHosts = [];
      int totalDiamonds = 0;

      // Populate hosts based on the agency's hosts array
      for (var hostId in hostIdsFromAgency) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(hostId)
              .get();

          if (!userDoc.exists) continue;

          final userData = userDoc.data() ?? {};
          final userDiamonds = _parseInt(userData['totalReceived'] ?? userData['diamonds'] ?? userData['balance'] ?? 0);
          final audioLiveDuration = _parseInt(userData['audioLiveDuration'] ?? 0);
          final videoLiveDuration = _parseInt(userData['videoLiveDuration'] ?? 0);

          final reqDoc = approvedRequestsMap[hostId];
          final reqData = reqDoc?.data();

          final item = {
            'docId': reqDoc?.id ?? '',
            'applicantId': hostId,
            'name': userData['displayName'] ?? userData['name'] ?? userData['holderName'] ?? 'Unknown',
            'displayId': userData['displayId']?.toString() ?? userData['id']?.toString() ?? hostId,
            'profileImage': _extractUserPhoto(userData),
            'liveType': reqData?['liveType'] ?? userData['liveType'] ?? 'Video Live',
            'createdAt': reqData?['createdAt'] ?? userData['createdAt'],
            'earnings': userDiamonds,
            'audioLiveDuration': audioLiveDuration,
            'videoLiveDuration': videoLiveDuration,
          };

          fetchedHosts.add(item);
          totalDiamonds += userDiamonds;
        } catch (e) {
          debugPrint('Error fetching user for host $hostId: $e');
        }
      }

      // Build pending requests list
      List<Map<String, dynamic>> fetchedRequests = [];
      for (var doc in pendingRequestDocs) {
        try {
          final data = doc.data();
          final applicantId = data['applicantId'] as String?;
          if (applicantId == null) continue;

          // Don't show in pending if already an active host in fetchedHosts
          if (fetchedHosts.any((h) => h['applicantId'] == applicantId)) continue;

          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(applicantId)
              .get();
          if (!userDoc.exists) continue;

          final userData = userDoc.data() ?? {};
          final userDiamonds = _parseInt(userData['totalReceived'] ?? userData['diamonds'] ?? userData['balance'] ?? 0);
          final audioLiveDuration = _parseInt(userData['audioLiveDuration'] ?? 0);
          final videoLiveDuration = _parseInt(userData['videoLiveDuration'] ?? 0);

          final item = {
            'docId': doc.id,
            'applicantId': applicantId,
            'name': userData['displayName'] ?? userData['name'] ?? userData['holderName'] ?? 'Unknown',
            'displayId': userData['displayId']?.toString() ?? userData['id']?.toString() ?? applicantId,
            'profileImage': _extractUserPhoto(userData),
            'liveType': data['liveType'] ?? 'Video Live',
            'createdAt': data['createdAt'],
            'earnings': userDiamonds,
            'audioLiveDuration': audioLiveDuration,
            'videoLiveDuration': videoLiveDuration,
          };

          fetchedRequests.add(item);
        } catch (e) {
          debugPrint('Error fetching pending request doc ${doc.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _hosts = fetchedHosts;
          _requests = fetchedRequests;
          _totalDiamonds = totalDiamonds;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching agency hosts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveRequest(String docId, String applicantId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // 1. Add host to agency's hosts array
      if (_agencyRef != null) {
        await _agencyRef!.update({
          'hosts': FieldValue.arrayUnion([applicantId])
        });
      } else {
        final agencyQuery = await FirebaseFirestore.instance
            .collection('agencies')
            .where('ownerId', isEqualTo: currentUser.uid)
            .limit(1)
            .get();
        if (agencyQuery.docs.isNotEmpty) {
          await agencyQuery.docs.first.reference.update({
            'hosts': FieldValue.arrayUnion([applicantId])
          });
        }
      }

      // 2. Update HostRequest status if docId exists
      if (docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('HostRequests').doc(docId).update({
          'status': 'approved',
          'islock': true,
          'isLock': true,
        });
      } else {
        final reqs = await FirebaseFirestore.instance
            .collection('HostRequests')
            .where('applicantId', isEqualTo: applicantId)
            .get();
        for (var d in reqs.docs) {
          await d.reference.update({
            'status': 'approved',
            'islock': true,
            'isLock': true,
          }).catchError((_) {});
        }
      }

      // 3. Update user to be a host and set islock to true
      final agId = _agencyId ?? currentUser.uid;
      await FirebaseFirestore.instance.collection('users').doc(applicantId).update({
        'isHost': true,
        'ishost': true,
        'role': 'host',
        'agencyId': agId,
        'islock': true,
        'isLock': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host request approved!')));
        _fetchData(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error approving request: $e')));
      }
    }
  }

  Future<void> _rejectRequest(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('HostRequests').doc(docId).update({
        'status': 'rejected',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host request rejected!')));
        _fetchData(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rejecting request: $e')));
      }
    }
  }

  Future<void> _removeHost(String docId, String applicantId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      // 1. Remove host from agency's hosts array
      if (_agencyRef != null) {
        await _agencyRef!.update({
          'hosts': FieldValue.arrayRemove([applicantId])
        });
      }

      if (currentUser != null) {
        final agencyQuery = await FirebaseFirestore.instance
            .collection('agencies')
            .where('ownerId', isEqualTo: currentUser.uid)
            .get();
        for (var doc in agencyQuery.docs) {
          if (doc.reference != _agencyRef) {
            await doc.reference.update({
              'hosts': FieldValue.arrayRemove([applicantId])
            }).catchError((_) {});
          }
        }
      }

      // 2. Delete HostRequest documents
      if (docId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('HostRequests').doc(docId).delete().catchError((_) {});
      }
      final extraReqs = await FirebaseFirestore.instance
          .collection('HostRequests')
          .where('applicantId', isEqualTo: applicantId)
          .get();
      for (var d in extraReqs.docs) {
        await d.reference.delete().catchError((_) {});
      }

      // 3. Update user profile
      await FirebaseFirestore.instance.collection('users').doc(applicantId).update({
        'isHost': false,
        'ishost': false,
        'role': 'user',
        'agencyId': FieldValue.delete(),
      }).catchError((_) {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host removed!')));
        _fetchData(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error removing host: $e')));
      }
    }
  }

  Widget _buildTopCard(String title, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF202636),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, color: iconColor, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off_rounded, color: Colors.white24, size: 80),
          SizedBox(height: 16),
          Text(
            'No active hosts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'No hosts found for this agency',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildHostList(List<Map<String, dynamic>> list, {bool isRequest = false}) {
    final filteredList = list.where((item) {
      final query = _searchQuery.toLowerCase();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final displayId = (item['displayId'] ?? '').toString().toLowerCase();
      return name.contains(query) || displayId.contains(query);
    }).toList();

    if (filteredList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchData,
        color: Colors.amber,
        backgroundColor: const Color(0xFF202636),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            _buildEmptyState(),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: Colors.amber,
      backgroundColor: const Color(0xFF202636),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final item = filteredList[index];
          final profileImage = (item['profileImage'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF202636),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                  onBackgroundImageError: profileImage.isNotEmpty ? (_, __) {} : null,
                  child: profileImage.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${item['displayId']} | ${item['liveType']}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (!isRequest) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.diamond, color: Colors.blueAccent, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Earnings: ${item['earnings']}',
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.videocam, color: Colors.white54, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(item['videoLiveDuration']),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.mic, color: Colors.white54, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(item['audioLiveDuration']),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isRequest)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _approveRequest(item['docId'], item['applicantId']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () => _rejectRequest(item['docId']),
                      ),
                    ],
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF202636),
                          title: const Text('Remove Host', style: TextStyle(color: Colors.white)),
                          content: Text(
                            'Are you sure you want to remove ${item['name']} from this agency?',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _removeHost(item['docId'], item['applicantId']);
                              },
                              child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131A2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Host Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF202636),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search hosts by ID or name...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                  prefixIcon: Icon(CupertinoIcons.search, color: Colors.amber, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          // Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildTopCard('BALANCE', _formatBalance(_userBalance), Icons.account_balance_wallet_rounded, Colors.greenAccent),
                const SizedBox(width: 8),
                _buildTopCard('HOST DIAMONDS', _totalDiamonds.toString(), Icons.diamond, Colors.blueAccent),
                const SizedBox(width: 8),
                _buildTopCard('TOTAL HOSTS', _hosts.length.toString(), Icons.people, Colors.amber),
              ],
            ),
          ),

          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF202636),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.amber.shade700,
                borderRadius: BorderRadius.circular(24),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                const Tab(text: 'HOSTS'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('REQUESTS'),
                      if (_requests.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_requests.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildHostList(_hosts),
                      _buildHostList(_requests, isRequest: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
