import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_udid/flutter_udid.dart';
import '../../data/local/secure_storage/secure_storage.dart';

class GlobalDeviceBanListener extends StatefulWidget {
  const GlobalDeviceBanListener({super.key});

  @override
  State<GlobalDeviceBanListener> createState() => _GlobalDeviceBanListenerState();
}

class _GlobalDeviceBanListenerState extends State<GlobalDeviceBanListener> {
  StreamSubscription<QuerySnapshot>? _deviceBanSub;
  bool _isBanned = false;

  @override
  void initState() {
    super.initState();
    _listenToDeviceBan();
  }

  Future<void> _listenToDeviceBan() async {
    try {
      final deviceId = await FlutterUdid.udid;
      _deviceBanSub = FirebaseFirestore.instance
          .collection('banned_devices')
          .where('deviceId', isEqualTo: deviceId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.metadata.isFromCache) return;
        
        final isBannedNow = snapshot.docs.isNotEmpty;
        if (isBannedNow && !_isBanned) {
          _signOut();
        }
        
        if (mounted && _isBanned != isBannedNow) {
          setState(() {
            _isBanned = isBannedNow;
          });
        }
      });
    } catch (e) {
      debugPrint("Error listening to device ban: $e");
    }
  }

  Future<void> _signOut() async {
    try {
      await GetIt.I<SecureStorage>().logout();
    } catch (_) {}
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  void dispose() {
    _deviceBanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isBanned) {
      return const SizedBox.shrink();
    }

    // Full screen overlay when banned
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
                'DEVICE BANNED',
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
                'This device has been permanently banned from accessing the app due to violations of our terms of service.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
