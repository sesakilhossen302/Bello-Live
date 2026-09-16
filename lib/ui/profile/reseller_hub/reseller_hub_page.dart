import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/remote/firebase/profile_services.dart';
import '../../../data/remote/firebase/reseller_services.dart';

class ResellerHubPage extends StatefulWidget {
  const ResellerHubPage({super.key});

  @override
  State<ResellerHubPage> createState() => _ResellerHubPageState();
}

class _ResellerHubPageState extends State<ResellerHubPage> {
  bool _isRechargeTab = true;
  int _resellerBalance = 0;
  bool _isLoadingBalance = true;
  StreamSubscription<int>? _balanceSubscription;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  SimpleUser? _searchedUser;
  bool _isSearching = false;
  bool _isTransferring = false;
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _listenToBalance();
  }

  void _listenToBalance() {
    _balanceSubscription = ProfileService.getCurrentUserBalanceStream().listen(
      (balance) {
        if (mounted) {
          setState(() {
            _resellerBalance = balance;
            _isLoadingBalance = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isLoadingBalance = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _balanceSubscription?.cancel();
    _searchController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = '';
      _searchedUser = null;
      _amountController.clear();
    });

    final user = await ResellerService.searchUserByDisplayId(query);

    setState(() {
      _isSearching = false;
      if (user != null) {
        _searchedUser = user;
      } else {
        _searchError = 'User not found';
      }
    });
  }

  Future<void> _transferBalance() async {
    if (_searchedUser == null) return;

    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) return;

    final amount = int.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (amount > _resellerBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insufficient balance')),
      );
      return;
    }

    setState(() {
      _isTransferring = true;
    });

    try {
      await ResellerService.transferResellerBalance(_searchedUser!.id, amount);
      
      // Update local balance
      setState(() {
        _resellerBalance = (_resellerBalance - amount).clamp(0, double.infinity).toInt();
        _searchedUser = null; // Reset form on success
        _searchController.clear();
        _amountController.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recharge successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTransferring = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Reseller Hub',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTabs(),
            const SizedBox(height: 24),
            Expanded(
              child: _isRechargeTab ? _buildRechargeView() : _buildHistoryView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRechargeTab = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isRechargeTab ? const Color(0xFFE62563) : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.diamond,
                      color: _isRechargeTab ? Colors.white : Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recharge',
                      style: TextStyle(
                        color: _isRechargeTab ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isRechargeTab = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isRechargeTab ? const Color(0xFFE62563) : Colors.transparent,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      color: !_isRechargeTab ? Colors.white : Colors.white54,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'History',
                      style: TextStyle(
                        color: !_isRechargeTab ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRechargeView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    _isLoadingBalance
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            NumberFormat('#,###').format(_resellerBalance),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.brown.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.diamond, color: Colors.blueAccent, size: 40),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Top Up User',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Search Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search User ID...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(CupertinoIcons.search, color: Color(0xFFE62563)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white54),
                  onPressed: _searchUser,
                ),
              ),
              onSubmitted: (_) => _searchUser(),
            ),
          ),
          const SizedBox(height: 32),
          
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else if (_searchError.isNotEmpty)
            Center(
              child: Text(
                _searchError,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          else if (_searchedUser != null)
            _buildUserFoundView()
          else
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(CupertinoIcons.search, size: 60, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          const Text(
            'Enter user ID to recharge',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildUserFoundView() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[800],
                backgroundImage: _searchedUser!.pictureUrl != null
                    ? CachedNetworkImageProvider(_searchedUser!.pictureUrl!)
                    : null,
                child: _searchedUser!.pictureUrl == null
                    ? const Icon(Icons.person, color: Colors.white54)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _searchedUser!.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${_searchController.text.trim()}',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.diamond, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isTransferring ? null : _transferBalance,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE62563),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isTransferring
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Recharge Now',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView() {
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: ResellerService.getResellerTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error loading history', style: TextStyle(color: Colors.white)));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text('No recharge history yet', style: TextStyle(color: Colors.white54)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data![index];
            final data = doc.data() as Map<String, dynamic>;
            final amount = data['amount'] ?? 0;
            final receiverName = data['receiverName'] ?? 'Unknown';
            final receiverDisplayId = data['receiverDisplayId'] ?? '';
            final timestamp = data['timestamp'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateFormat('MMM dd, yyyy - hh:mm a').format(timestamp.toDate())
                : 'Just now';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward, color: Colors.blueAccent, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receiverName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: $receiverDisplayId | $dateStr',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '-$amount',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Icon(Icons.diamond, color: Colors.blueAccent, size: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
