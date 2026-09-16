import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

class CoinSellerPortalPage extends StatefulWidget {
  const CoinSellerPortalPage({super.key});

  @override
  State<CoinSellerPortalPage> createState() => _CoinSellerPortalPageState();
}

class _CoinSellerPortalPageState extends State<CoinSellerPortalPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayIdController = TextEditingController();
  final _amountController = TextEditingController();

  final _requestFormKey = GlobalKey<FormState>();
  final _requestAmountController = TextEditingController();
  final _requestNoteController = TextEditingController();

  bool _isLoading = false;
  bool _isRequesting = false;

  @override
  void dispose() {
    _displayIdController.dispose();
    _amountController.dispose();
    _requestAmountController.dispose();
    _requestNoteController.dispose();
    super.dispose();
  }

  Future<void> _sendCoins() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    final String targetDisplayId = _displayIdController.text.trim();
    final int? amount = int.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ProfileService.transferCoinsAsReseller(targetDisplayId, amount);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coins sent successfully!')),
        );
        _displayIdController.clear();
        _amountController.clear();
      }
    } catch (e) {
      if (mounted) {
        // e.toString() might have "Exception: " at the beginning. 
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
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

  Future<void> _requestCoins() async {
    if (!_requestFormKey.currentState!.validate() || _isRequesting) return;

    final int? amount = int.tryParse(_requestAmountController.text.trim());
    final String note = _requestNoteController.text.trim();

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    try {
      await ProfileService.requestCoinsAsReseller(amount, note);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Coin request sent successfully to Admin!')),
        );
        _requestAmountController.clear();
        _requestNoteController.clear();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildBalanceDisplay(),
                        const SizedBox(height: 30),
                        _buildTransferForm(),
                        const SizedBox(height: 30),
                        _buildRequestCoinsForm(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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
            'Coin Seller Portal',
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
          IconButton(
            icon: Icon(CupertinoIcons.clock_fill, size: 28, color: AppColors.pink),
            onPressed: () {
              context.push(Routes.coinSellerHistory.path);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return StreamBuilder<int>(
      stream: ProfileService.getCurrentUserBalanceStream(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    'Available Balance',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.diamond, color: Colors.cyanAccent, size: 36),
                      const SizedBox(width: 10),
                      Text(
                        _formatNumber(balance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestCoinsForm() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text(
          'Request Coins from Admin',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconColor: Colors.amber,
        collapsedIconColor: Colors.white70,
        children: [
          Form(
            key: _requestFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildGlassyTextField(
                  controller: _requestAmountController,
                  label: 'Amount of Coins',
                  icon: CupertinoIcons.money_dollar_circle_fill,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v!.isEmpty) return 'Amount is required';
                    if (int.tryParse(v) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                _buildGlassyTextField(
                  controller: _requestNoteController,
                  label: 'Note (Optional)',
                  icon: CupertinoIcons.text_aligncenter,
                  keyboardType: TextInputType.text,
                  validator: (v) => null, // Optional
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isRequesting ? null : _requestCoins,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withValues(alpha: 0.9),
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                    ),
                    child: _isRequesting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transfer Coins',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildGlassyTextField(
            controller: _displayIdController,
            label: 'User Display ID',
            icon: CupertinoIcons.person_solid,
            keyboardType: TextInputType.number,
            validator: (v) => v!.isEmpty ? 'User ID is required' : null,
          ),
          const SizedBox(height: 20),
          _buildGlassyTextField(
            controller: _amountController,
            label: 'Amount of Coins',
            icon: CupertinoIcons.money_dollar_circle_fill,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v!.isEmpty) return 'Amount is required';
              if (int.tryParse(v) == null) return 'Enter a valid number';
              return null;
            },
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendCoins,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Send Coins',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
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
                child: Icon(icon, color: AppColors.pinkLight, size: 24),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: keyboardType,
                  inputFormatters: keyboardType == TextInputType.number 
                      ? [FilteringTextInputFormatter.digitsOnly] 
                      : [],
                  style: const TextStyle(color: Colors.white, fontSize: 18),
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}
