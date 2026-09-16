import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../theme/app_theme.dart';

class ApplyCoinSellerPage extends StatefulWidget {
  const ApplyCoinSellerPage({super.key});

  @override
  State<ApplyCoinSellerPage> createState() => _ApplyCoinSellerPageState();
}

class _ApplyCoinSellerPageState extends State<ApplyCoinSellerPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  String? _applicationStatus;
  Map<String, dynamic>? _applicationData;

  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _checkApplicationStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final statusDoc = await ProfileService.getCoinSellerApplicationStatus();
      if (statusDoc.exists) {
        final data = statusDoc.data() as Map<String, dynamic>;
        setState(() {
          _applicationStatus = data['status'];
          _applicationData = data;
        });
      }
    } catch (e) {
      debugPrint('Error checking coin seller status: $e');
    } finally {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ProfileService.applyForCoinSeller(
        name: _nameController.text.trim(),
        whatsappNumber: _whatsappController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted successfully!')),
        );
        _formKey.currentState?.reset();
        _nameController.clear();
        _whatsappController.clear();
        _checkApplicationStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting application: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelApplication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Cancel Application', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to cancel your Coin Seller application?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Cancel', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await ProfileService.cancelCoinSellerApplication();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application cancelled successfully')),
          );
          setState(() {
            _applicationStatus = null;
            _applicationData = null;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error cancelling application: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
                _buildHeader(),
                Expanded(
                  child: _isCheckingStatus
                      ? Center(child: CircularProgressIndicator(color: AppColors.pink))
                      : _applicationStatus != null
                          ? (_applicationStatus == 'active'
                              ? _buildApprovedDisplay()
                              : _applicationStatus == 'reject'
                                  ? _buildRejectedDisplay()
                                  : _buildPendingDisplay())
                          : _buildForm(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            'Apply for Coin Seller',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.pink.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
          ),
          const Spacer(),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: AppColors.pink, strokeWidth: 2),
              ),
            )
          else if (_applicationStatus == null)
            TextButton(
              onPressed: _submitApplication,
              child: Text(
                'Submit',
                style: TextStyle(color: AppColors.pink, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildGlassyTextField(
              controller: _nameController,
              label: 'Real Name',
              icon: CupertinoIcons.person_fill,
              validator: (v) => v!.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 20),
            _buildGlassyTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number',
              icon: Icons.message,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'WhatsApp number is required' : null,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassyTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Icon(icon, color: AppColors.pinkLight, size: 20),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: keyboardType,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(right: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingDisplay() {
    if (_applicationData == null) return const SizedBox();

    final String name = _applicationData!['name'] ?? 'N/A';
    final String whatsappNumber = _applicationData!['whatsappNumber'] ?? 'N/A';
    final submittedAt = _applicationData!['submittedAt'];

    String submittedDate = 'N/A';
    if (submittedAt != null) {
      try {
        final timestamp = submittedAt as dynamic;
        final dateTime = timestamp.toDate();
        submittedDate = DateFormat('MMM dd, yyyy').format(dateTime);
      } catch (e) {
        submittedDate = 'N/A';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Icon(CupertinoIcons.clock_fill, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Application Pending',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your Coin Seller application is under review',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildInfoCard('Name', name, CupertinoIcons.person_fill),
          const SizedBox(height: 15),
          _buildInfoCard('WhatsApp Number', whatsappNumber, Icons.message),
          const SizedBox(height: 15),
          _buildInfoCard('Submitted On', submittedDate, CupertinoIcons.calendar),
          const SizedBox(height: 10),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRejectedDisplay() {
    if (_applicationData == null) return const SizedBox();

    final String name = _applicationData!['name'] ?? 'N/A';
    final String whatsappNumber = _applicationData!['whatsappNumber'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red.shade400, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Application Rejected',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your Coin Seller application was not approved',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildInfoCard('Name', name, CupertinoIcons.person_fill),
          const SizedBox(height: 15),
          _buildInfoCard('WhatsApp Number', whatsappNumber, Icons.message),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              // Same logic as cancel, but text says Re-apply
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text('Re-apply', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'Your previous application will be deleted and you can submit a new one. Continue?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Continue', style: TextStyle(color: AppColors.pink)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                setState(() => _isLoading = true);
                try {
                  await ProfileService.cancelCoinSellerApplication();
                  if (mounted) {
                    setState(() {
                      _applicationStatus = null;
                      _applicationData = null;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('You can now submit a new application')),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            label: const Text('Re-apply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApprovedDisplay() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C9A7), Color(0xFF0097A7)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C9A7).withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.checkmark_alt, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'You are a Coin Seller',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your application has been approved',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.pinkLight, size: 24),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
