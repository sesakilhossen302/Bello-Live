import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:picture_live/theme/app_theme.dart';

class HostApprovalPage extends StatefulWidget {
  final String agencyCode;
  
  const HostApprovalPage({super.key, required this.agencyCode});

  @override
  State<HostApprovalPage> createState() => _HostApprovalPageState();
}

class _HostApprovalPageState extends State<HostApprovalPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _approveHost(String docId, Map<String, dynamic> data) async {
    try {
      final userId = data['userId'] as String;
      final hostType = data['hostType'] as String;
      final agencyCode = data['agencyCode'] as String;

      final batch = _firestore.batch();
      
      // Update application status
      batch.update(_firestore.collection('hosting_applications').doc(docId), {
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user profile
      batch.update(_firestore.collection('users').doc(userId), {
        'isHost': true,
        'hostType': hostType,
        'agencyCode': agencyCode,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host Approved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving host: $e')),
        );
      }
    }
  }

  Future<void> _rejectHost(String docId) async {
    try {
      await _firestore.collection('hosting_applications').doc(docId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host Rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting host: $e')),
        );
      }
    }
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
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(CupertinoIcons.back, color: Colors.white, size: 24),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Host Approvals',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('hosting_applications')
                        .where('agencyCode', isEqualTo: widget.agencyCode)
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.pink));
                      }
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading requests', style: TextStyle(color: Colors.white70)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No pending host approvals.', style: TextStyle(color: Colors.white70, fontSize: 16)));
                      }

                      final docs = snapshot.data!.docs;
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        physics: const BouncingScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final selfieUrl = data['selfieUrl'] as String?;
                          final hostType = data['hostType'] ?? 'Unknown';
                          final idNumber = data['idNumber'] ?? 'N/A';
                          
                          final userId = data['userId'] as String;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
                            ),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                collapsedIconColor: Colors.white70,
                                iconColor: AppColors.pink,
                                title: Text('ID: $idNumber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                subtitle: Text('Type: $hostType', style: const TextStyle(color: Colors.white70)),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.pink.withValues(alpha: 0.2),
                                  backgroundImage: selfieUrl != null ? NetworkImage(selfieUrl) : null,
                                  child: selfieUrl == null ? const Icon(Icons.person, color: Colors.white) : null,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: FutureBuilder<DocumentSnapshot>(
                                      future: _firestore.collection('users').doc(userId).get(),
                                      builder: (context, userSnapshot) {
                                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                                          return const Center(child: CircularProgressIndicator(color: AppColors.pink));
                                        }
                                        
                                        String name = 'Unknown';
                                        String displayId = 'N/A';
                                        String? userPhoto;
                                        
                                        if (userSnapshot.hasData && userSnapshot.data!.exists) {
                                          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                                          name = userData['displayName'] ?? userData['name'] ?? 'Unknown';
                                          displayId = userData['displayId'] ?? 'N/A';
                                          userPhoto = userData['photoUrl'];
                                        }

                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 30,
                                                  backgroundColor: Colors.white10,
                                                  backgroundImage: userPhoto != null ? NetworkImage(userPhoto) : null,
                                                  child: userPhoto == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text('Name: $name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                                      const SizedBox(height: 4),
                                                      Text('Display ID: $displayId', style: const TextStyle(color: Colors.white70)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            const Text('Selfie Image:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                            const SizedBox(height: 8),
                                            if (selfieUrl != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.network(selfieUrl, height: 200, width: double.infinity, fit: BoxFit.cover),
                                              ),
                                            const SizedBox(height: 24),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () => _rejectHost(doc.id),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.redAccent,
                                                      side: const BorderSide(color: Colors.redAccent),
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _approveHost(doc.id, data),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.green,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
}
