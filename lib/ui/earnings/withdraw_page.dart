import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/remote/firebase/profile_services.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  int _selectedTab = 0; // 0: Withdraw, 1: History
  String _selectedPaymentMethod = 'Bkash';
  String _selectedLiveType = 'Video';

  final _accountController = TextEditingController();
  final _diamondsController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  int _userDiamonds = 0;
  String? _userId;
  StreamSubscription? _userSubscription;

  final List<String> _paymentMethods = ['Bkash', 'Nagad', 'Rocket', 'Bank Transfer'];
  final List<String> _liveTypes = ['Audio', 'Video'];

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _listenToUserDiamonds();
  }

  void _listenToUserDiamonds() {
    if (_userId == null) return;
    _userSubscription = ProfileService.getUserProfileStream(_userId!).listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userDiamonds = (data['balance'] as num?)?.toInt() ?? 0;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _accountController.dispose();
    _diamondsController.dispose();
    super.dispose();
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final inputDiamonds = int.tryParse(_diamondsController.text.trim()) ?? 0;
    if (inputDiamonds < 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum withdrawal amount is 100,000 diamonds')),
      );
      return;
    }

    if (inputDiamonds > _userDiamonds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient diamond balance')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_userId != null) {
        await FirebaseFirestore.instance.collection('WithdrawRequests').add({
          'userId': _userId,
          'accountNumber': _accountController.text.trim(),
          'diamonds': inputDiamonds,
          'paymentMethod': _selectedPaymentMethod,
          'liveType': _selectedLiveType,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Deduct from Earning coins (balance)
        await FirebaseFirestore.instance.collection('users').doc(_userId).update({
          'balance': FieldValue.increment(-inputDiamonds),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Withdrawal request submitted successfully!'),
              backgroundColor: Color(0xFF5A189A),
            ),
          );
          _accountController.clear();
          _diamondsController.clear();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit withdrawal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar with Tabs
            Container(
              color: const Color(0xFF5A189A),
              child: Column(
                children: [
                  // App Bar Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(CupertinoIcons.back, color: Colors.white, size: 26),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Withdraw Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Sub Tabs (Withdraw vs History)
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderTab(
                          index: 0,
                          icon: Icons.diamond_outlined,
                          title: 'Withdraw',
                        ),
                      ),
                      Expanded(
                        child: _buildHeaderTab(
                          index: 1,
                          icon: Icons.history,
                          title: 'History',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Body Content
            Expanded(
              child: _selectedTab == 0 ? _buildWithdrawTab() : _buildHistoryTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTab({
    required int index,
    required IconData icon,
    required String title,
  }) {
    final bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 3,
            width: 80,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1C1C1E) : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Remaining Diamonds Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5A189A), Color(0xFF2C132B)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5A189A).withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.diamond_rounded, color: Color(0xFF4FC3F7), size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_userDiamonds',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Your remaining earning coins',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Rate Banners
            _buildRateBanner('100000 diamond = 900.00 BDT'),
            const SizedBox(height: 10),
            _buildRateBanner('200000 diamond = 1800.00 BDT'),
            const SizedBox(height: 10),
            _buildRateBanner('500000 diamond = 4500.00 BDT'),
            const SizedBox(height: 16),

            // 3. Payment Method Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E42),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5A189A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPaymentMethod,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF162B5B),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        items: _paymentMethods.map((String method) {
                          String? assetPath;
                          if (method == 'Bkash') assetPath = 'assets/logo/BKash.svg';
                          if (method == 'Nagad') assetPath = 'assets/logo/Nagad.svg';
                          if (method == 'Rocket') assetPath = 'assets/logo/rocket.svg';

                          return DropdownMenuItem<String>(
                            value: method,
                            child: Row(
                              children: [
                                if (assetPath != null) ...[
                                  SvgPicture.asset(assetPath, width: 24, height: 24),
                                  const SizedBox(width: 12),
                                ] else if (method == 'Bank Transfer') ...[
                                  const Icon(Icons.account_balance, color: Color(0xFF5A189A), size: 24),
                                  const SizedBox(width: 12),
                                ],
                                Text(method),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedPaymentMethod = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Live Type Selector
            const Text(
              "What's your Live Type?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: _liveTypes.map((type) {
                final bool isSelected = _selectedLiveType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedLiveType = type),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? const Color(0xFF5A189A) : Colors.white54,
                          size: 22,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          type,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 5. Account Number Input
            _buildInputField(
              controller: _accountController,
              hintText: 'Account Number',
              keyboardType: TextInputType.phone,
              validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter account number' : null,
            ),
            const SizedBox(height: 14),

            // 6. Diamonds Input
            _buildInputField(
              controller: _diamondsController,
              hintText: 'Diamonds (Min 100,000)',
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Please enter diamond amount';
                final amount = int.tryParse(val.trim()) ?? 0;
                if (amount < 100000) return 'Minimum amount is 100,000';
                return null;
              },
            ),
            const SizedBox(height: 28),

            // 7. Submit Withdrawal Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitWithdrawal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A189A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Submit Withdrawal',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildRateBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD1DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFC2185B),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_userId == null) {
      return const Center(child: Text('Please log in to view history'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('WithdrawRequests')
          .where('userId', isEqualTo: _userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF5A189A)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No withdrawal history found',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final diamonds = data['diamonds'] ?? 0;
            final method = data['paymentMethod'] ?? 'Bkash';
            final status = data['status'] ?? 'pending';
            final account = data['accountNumber'] ?? '';

            Color statusColor = Colors.orange;
            if (status == 'approved') statusColor = Colors.green;
            if (status == 'rejected') statusColor = Colors.red;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E42),
                borderRadius: BorderRadius.circular(14),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A189A).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.diamond_outlined, color: Color(0xFF5A189A), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$diamonds Diamonds ($method)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Account: $account',
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
