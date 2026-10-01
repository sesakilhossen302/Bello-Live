import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ApplyHostingPage extends StatefulWidget {
  const ApplyHostingPage({super.key});

  @override
  State<ApplyHostingPage> createState() => _ApplyHostingPageState();
}

class _ApplyHostingPageState extends State<ApplyHostingPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _agencies = [];
  
  final Set<String> _pendingAgencyIds = {};
  final Map<String, String> _pendingRequestDocIds = {};
  final Map<String, dynamic> _pendingRequestDetails = {};
  
  String? _approvedAgencyId;
  Map<String, dynamic> _approvedAgencyDetails = {};

  @override
  void initState() {
    super.initState();
    _fetchAgencies();
  }

  Future<void> _fetchAgencies() async {
    try {
      List<Map<String, dynamic>> fetched = [];
      _approvedAgencyId = null;
      _approvedAgencyDetails = {};

      // Fetch approved agencies from the agencies collection
      final agenciesSnapshot = await FirebaseFirestore.instance
          .collection('agencies')
          .where('status', isEqualTo: 'active') // Only fetch active agencies
          .get();

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final pendingIds = <String>{};
      final requestDocs = <String, String>{};

      if (currentUserId != null) {
        final requestsSnapshot = await FirebaseFirestore.instance
            .collection('HostRequests')
            .where('applicantId', isEqualTo: currentUserId)
            .where('status', whereIn: ['pending', 'approved'])
            .get();

        for (var doc in requestsSnapshot.docs) {
          final data = doc.data();
          final agId = data['agencyId'] ?? data['agentUserId'];
          final status = data['status'];
          if (agId != null) {
            if (status == 'approved') {
              _approvedAgencyId = agId.toString();
              requestDocs[agId.toString()] = doc.id;
              _approvedAgencyDetails = data;
            } else if (status == 'pending') {
              pendingIds.add(agId.toString());
              requestDocs[agId.toString()] = doc.id;
              _pendingRequestDetails[agId.toString()] = data;
            }
          }
        }
      }

      for (var doc in agenciesSnapshot.docs) {
        final data = doc.data();
        final displayId = (data['agencyId'] ?? data['agencyCode'] ?? data['displayId'] ?? data['id'] ?? doc.id).toString();
        
        if (!fetched.any((element) => element['agentUserId'] == displayId)) {
          fetched.add({
            'id': doc.id,
            'agentUserId': displayId,
            'ownerId': (data['ownerId'] ?? '').toString(),
            'name': (data['name'] ?? data['agencyName'] ?? 'Agency').toString(),
            'profileImage': (data['logo'] ?? data['profileImage'] ?? data['photoUrl'] ?? data['avatar'] ?? '').toString(),
          });
        }
      }

      setState(() {
        _agencies = fetched;
        _pendingAgencyIds.clear();
        _pendingAgencyIds.addAll(pendingIds);
        _pendingRequestDocIds.clear();
        _pendingRequestDocIds.addAll(requestDocs);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _agencies = [];
        _isLoading = false;
      });
    }
  }

  void _showHostRequestDialog(Map<String, dynamic> agency) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFF162B5B),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Agent ID Title
                Text(
                  'Agent User ID: ${agency['agentUserId']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                const Text(
                  'Do you wanna send host request to this Agent?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 16),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose Live Type:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Audio Live Button (Green)
                _buildLiveTypeButton(
                  title: 'Audio Live',
                  icon: Icons.music_note_rounded,
                  color: const Color(0xFF4CAF50),
                  onTap: () {
                    Navigator.pop(context);
                    _sendHostRequest(agency, 'Audio Live');
                  },
                ),
                const SizedBox(height: 10),

                // 2. Video Live Button (Red)
                _buildLiveTypeButton(
                  title: 'Video Live',
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFFFF5252),
                  onTap: () {
                    Navigator.pop(context);
                    _sendHostRequest(agency, 'Video Live');
                  },
                ),
                const SizedBox(height: 16),

                // Cancel Button
                SizedBox(
                  width: 120,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                      side: const BorderSide(color: Color(0xFF2196F3), width: 1.8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveTypeButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendHostRequest(Map<String, dynamic> agency, String liveType) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final docRef = await FirebaseFirestore.instance.collection('HostRequests').add({
        'applicantId': currentUserId,
        'agentUserId': agency['agentUserId'],
        'ownerId': agency['ownerId'],
        'agencyId': agency['agentUserId'],
        'agentName': agency['name'],
        'liveType': liveType,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _pendingAgencyIds.add(agency['agentUserId'].toString());
        _pendingRequestDocIds[agency['agentUserId'].toString()] = docRef.id;
        _pendingRequestDetails[agency['agentUserId'].toString()] = {
          'liveType': liveType,
          'createdAt': DateTime.now().toString(),
        };
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Host request sent to ${agency['name']} ($liveType)!'),
            backgroundColor: const Color(0xFF5A189A),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    }
  }

  Future<void> _cancelHostRequest(String agencyId) async {
    final docId = _pendingRequestDocIds[agencyId];
    if (docId == null) return;
    
    try {
      await FirebaseFirestore.instance.collection('HostRequests').doc(docId).delete();
      setState(() {
        _pendingAgencyIds.remove(agencyId);
        _pendingRequestDocIds.remove(agencyId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request cancelled successfully.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel request: $e')),
        );
      }
    }
  }

  String _formatDate(dynamic dt) {
    if (dt == null) return '';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is String) {
      return dt;
    } else {
      date = DateTime.now();
    }
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayStr = days[date.weekday - 1];
    final hr = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    final sec = date.second.toString().padLeft(2, '0');
    return '$dayStr, ${date.month}/${date.day}/${date.year} $hr:$min:$sec $ampm';
  }

  Widget _buildApprovedUI() {
    final agencyName = _approvedAgencyDetails['agentName'] ?? 'Agency';
    final liveType = _approvedAgencyDetails['liveType'] ?? 'Video Live';
    final agencyId = _approvedAgencyId!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: const Color(0xFF5A189A),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 50),
                const SizedBox(height: 16),
                const Text(
                  'You are an Approved Host!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Agency: $agencyName',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: $agencyId',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: $liveType',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingUI() {
    final pendingId = _pendingAgencyIds.first;
    final details = _pendingRequestDetails[pendingId] ?? {};
    final liveType = details['liveType'] ?? 'Video Live';
    final dateStr = _formatDate(details['createdAt']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              color: const Color(0xFF5A189A),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Your host request ($liveType) is\npending. Please wait.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 140,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _cancelHostRequest(pendingId),
              icon: const Icon(Icons.power_settings_new, color: Color(0xFF5A189A), size: 20),
              label: const Text('Remove', style: TextStyle(color: Color(0xFF5A189A), fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredAgencies = _agencies.where((agency) {
      final id = (agency['agentUserId'] ?? '').toString().toLowerCase();
      final name = (agency['name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return id.contains(query) || name.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              color: const Color(0xFF5A189A),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Host Request',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF5A189A)))
                  : _approvedAgencyId != null
                      ? _buildApprovedUI()
                      : _pendingAgencyIds.isNotEmpty 
                          ? _buildPendingUI() 
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Column(
                            children: [                               // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1E42),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: 'Search agent with UserID here',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          suffixIcon: Icon(CupertinoIcons.search, color: Colors.white70, size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Agency List
                    Expanded(
                      child: filteredAgencies.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching agents found',
                                    style: TextStyle(color: Colors.white70, fontSize: 15),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredAgencies.length,
                                    itemBuilder: (context, index) {
                                      final agency = filteredAgencies[index];
                                      final isPending = _pendingAgencyIds.contains(agency['agentUserId'].toString());
                                      return GestureDetector(
                                        onTap: () {
                                          if (!isPending) {
                                            _showHostRequestDialog(agency);
                                          }
                                        },
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F1E42),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 6,
                                                ),
                                              ],
                                            ),
                                          child: Row(
                                          children: [
                                            Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.grey.shade300,
                                              ),
                                              child: ClipOval(
                                                child: (agency['profileImage'] != null && agency['profileImage'].toString().isNotEmpty)
                                                    ? Image.network(
                                                        agency['profileImage'],
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.grey),
                                                      )
                                                    : const Icon(Icons.person, color: Colors.grey, size: 30),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Agent User ID: ${agency['agentUserId']}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Name: ${agency['name']}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isPending)
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  const Text(
                                                    'Submitted',
                                                    style: TextStyle(
                                                      color: Color(0xFF4CAF50),
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  SizedBox(
                                                    height: 30,
                                                    child: ElevatedButton(
                                                      onPressed: () => _cancelHostRequest(agency['agentUserId'].toString()),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFFFF5252),
                                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                                      ),
                                                      child: const Text('Cancel', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            else
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.transparent,
                                                ),
                                                child: const Icon(
                                                  Icons.touch_app_outlined,
                                                  color: Color(0xFF5A189A),
                                                  size: 24,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
