import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_it/get_it.dart';
import '../../data/local/secure_storage/secure_storage.dart';

class UserBlockListener extends StatefulWidget {
  const UserBlockListener({super.key});

  @override
  State<UserBlockListener> createState() => _UserBlockListenerState();
}

class _UserBlockListenerState extends State<UserBlockListener> {
  StreamSubscription<DocumentSnapshot>? _sub;
  StreamSubscription<QuerySnapshot>? _emailBanSub;
  bool _isBlocked = false;
  bool _isEmailBanned = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _sub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
        if (doc.metadata.isFromCache) return; // Ignore stale cached data during login

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>?;
          final isBlockedNow = data != null && data['isBlocked'] == true;
          
          if (mounted && _isBlocked != isBlockedNow) {
            setState(() {
              _isBlocked = isBlockedNow;
            });
          }
        }
      });

      if (user.email != null && user.email!.isNotEmpty) {
        _emailBanSub = FirebaseFirestore.instance
            .collection('banned_emails')
            .where('email', isEqualTo: user.email)
            .snapshots()
            .listen((snapshot) {
          if (snapshot.metadata.isFromCache) return;
          
          final isBannedNow = snapshot.docs.isNotEmpty;
          if (mounted && _isEmailBanned != isBannedNow) {
            setState(() {
              _isEmailBanned = isBannedNow;
            });
          }
        });
      }
    }
  }

  Future<void> _signOut() async {
    _sub?.cancel();
    _emailBanSub?.cancel();
    
    try {
      await GetIt.I<SecureStorage>().logout();
    } catch (_) {}
    
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _emailBanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBlocked && !_isEmailBanned) {
      return const SizedBox.shrink();
    }

    // Full screen overlay when account is blocked
    return Scaffold(
      backgroundColor: const Color(0xFF131A2A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.nosign,
                  color: Colors.redAccent,
                  size: 100,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'ACCOUNT BANNED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account has been permanently banned from accessing the app due to violations of our terms of service.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _signOut,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'LOGOUT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
