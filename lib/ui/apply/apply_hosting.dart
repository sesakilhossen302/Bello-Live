import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../theme/app_theme.dart';

class ApplyHostingPage extends StatefulWidget {
  const ApplyHostingPage({super.key});

  @override
  State<ApplyHostingPage> createState() => _ApplyHostingPageState();
}

class _ApplyHostingPageState extends State<ApplyHostingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  String? _applicationStatus;
  Map<String, dynamic>? _applicationData;
  String? _conflictingApplicationError;

  final _idNumberController = TextEditingController();
  final _agencyCodeController = TextEditingController();

  String? _selectedHostType;
  String? _selectedCountryName;
  String? _selectedCountryFlagEmoji;
  File? _selfieImage;

  @override
  void initState() {
    super.initState();
    _generateHostId();
    _checkApplicationStatus();
  }

  void _generateHostId() {
    final random = Random();
    final randomDigits = 100000 + random.nextInt(900000);
    _idNumberController.text = 'H$randomDigits';
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _agencyCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkApplicationStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final statusDoc = await ProfileService.getHostingApplicationStatus();
      if (statusDoc.exists) {
        final data = statusDoc.data() as Map<String, dynamic>;
        setState(() {
          _applicationStatus = data['status'];
          _applicationData = data;
        });
      }
      // No conflict check — a user can be both Host and Agency
    } catch (e) {
      debugPrint('Error checking hosting status: $e');
    } finally {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selfieImage = File(picked.path));
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    if (_selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a selfie.')));
      return;
    }
    if (_selectedHostType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a host type.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ProfileService.applyForHosting(
        idNumber: _idNumberController.text.trim(),
        hostType: _selectedHostType!,
        location: _selectedCountryName ?? 'N/A',
        locationFlag: _selectedCountryFlagEmoji,
        agencyCode: _agencyCodeController.text.trim(),
        selfieFile: _selfieImage!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application submitted successfully!')));
        _checkApplicationStatus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelApplication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Cancel Application',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to cancel your hosting application?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red.shade400))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ProfileService.cancelHostingApplication();
      if (mounted) {
        setState(() {
          _applicationStatus = null;
          _applicationData = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application cancelled.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reApply() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Re-apply for Hosting',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Your previous application will be deleted. Continue?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Continue',
                  style: TextStyle(color: AppColors.pink))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ProfileService.cancelHostingApplication();
      if (mounted) {
        setState(() {
          _applicationStatus = null;
          _applicationData = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isCheckingStatus
                    ? Center(
                        child: CircularProgressIndicator(color: AppColors.pink))
                    : _conflictingApplicationError != null
                        ? _buildErrorDisplay(_conflictingApplicationError!)
                        : _applicationStatus == 'approved'
                            ? _buildApprovedDisplay()
                            : _applicationStatus == 'reject'
                                ? _buildRejectedDisplay()
                                : _applicationStatus == 'pending'
                                    ? _buildPendingDisplay()
                                    : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 20, bottom: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            'Apply for Hosting',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                    color: Colors.pink.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
            ),
          ),
          const Spacer(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      color: AppColors.pink, strokeWidth: 2)),
            )
          else if (_applicationStatus == null &&
              _conflictingApplicationError == null)
            TextButton(
              onPressed: _submitApplication,
              child: Text('Submit',
                  style: TextStyle(
                      color: AppColors.pink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorDisplay(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.xmark_octagon_fill,
                color: Colors.red.shade400, size: 80),
            const SizedBox(height: 20),
            const Text('Application Blocked',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDisplay() {
    if (_applicationData == null) return const SizedBox();
    final data = _applicationData!;
    final submittedDate = _formatDate(data['submittedAt']);
    final location = data['location'] ?? 'N/A';
    final flag = data['locationFlag'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(CupertinoIcons.clock_fill, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          const Text('Application Pending',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Your hosting application is under review',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          const SizedBox(height: 30),
          _infoCard('ID Number', data['idNumber'] ?? 'N/A',
              CupertinoIcons.number),
          const SizedBox(height: 12),
          _infoCard('Host Type', data['hostType'] ?? 'N/A',
              CupertinoIcons.star_fill),
          const SizedBox(height: 12),
          _infoCard('Location', flag != null ? '$flag $location' : location,
              CupertinoIcons.location_solid),
          const SizedBox(height: 12),
          _infoCard('Agency Code', data['agencyCode'] ?? 'N/A',
              CupertinoIcons.building_2_fill),
          const SizedBox(height: 12),
          _infoCard('Submitted On', submittedDate, CupertinoIcons.calendar),
          if ((data['selfieUrl'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 20),
            _imageCard('Selfie', data['selfieUrl'] as String),
          ],
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _cancelApplication,
            icon: const Icon(CupertinoIcons.xmark_circle_fill),
            label: const Text('Cancel Application'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRejectedDisplay() {
    if (_applicationData == null) return const SizedBox();
    final data = _applicationData!;
    final reason = data['reason'] as String?;
    final location = data['location'] ?? 'N/A';
    final flag = data['locationFlag'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(CupertinoIcons.xmark_circle_fill,
              color: Colors.red.shade400, size: 80),
          const SizedBox(height: 20),
          const Text('Application Rejected',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Your hosting application was not approved',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(CupertinoIcons.info_circle_fill,
                            color: Colors.red.shade300, size: 20),
                        const SizedBox(width: 10),
                        Text('Rejection Reason',
                            style: TextStyle(
                                color: Colors.red.shade300,
                                fontSize: 14,
                                fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 10),
                      Text(reason,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 30),
          const Text('Previous Application Details',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _infoCard('ID Number', data['idNumber'] ?? 'N/A',
              CupertinoIcons.number),
          const SizedBox(height: 12),
          _infoCard('Host Type', data['hostType'] ?? 'N/A',
              CupertinoIcons.star_fill),
          const SizedBox(height: 12),
          _infoCard('Location', flag != null ? '$flag $location' : location,
              CupertinoIcons.location_solid),
          const SizedBox(height: 12),
          _infoCard('Agency Code', data['agencyCode'] ?? 'N/A',
              CupertinoIcons.building_2_fill),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _reApply,
            icon: const Icon(CupertinoIcons.arrow_clockwise),
            label: const Text('Re-apply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildApprovedDisplay() {
    final data = _applicationData;
    // hostId may be int — convert safely
    final String hostId =
        (data?['hostId'] ?? data?['idNumber'] ?? 'N/A').toString();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<Map<String, dynamic>?>(
      future: uid.isEmpty
          ? Future.value(null)
          : ProfileService.getUserProfile(uid).then((doc) {
              if (!doc.exists) return null;
              return doc.data() as Map<String, dynamic>;
            }),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final String name = profile?['displayName'] ?? 'Host';
        final String? photoUrl =
            profile?['photoUrl'] as String?;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                // ── Glassy Host Card ──────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color:
                              const Color(0xFFFF6B9D).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF3C78)
                                .withValues(alpha: 0.15),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // ── Approved badge chip ──
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B9D),
                                  Color(0xFFFF3C78)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B9D)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 10,
                                )
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.checkmark_seal_fill,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'Approved Host',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Profile Image ──
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF6B9D),
                                  Color(0xFFFF3C78)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B9D)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: (photoUrl != null &&
                                      photoUrl.isNotEmpty)
                                  ? CachedNetworkImage(
                                      imageUrl: photoUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: Colors.white10,
                                        child: const Icon(
                                          CupertinoIcons.person_fill,
                                          color: Colors.white54,
                                          size: 40,
                                        ),
                                      ),
                                      errorWidget: (_, __, ___) =>
                                          Container(
                                        color: Colors.white10,
                                        child: const Icon(
                                          CupertinoIcons.person_fill,
                                          color: Colors.white54,
                                          size: 40,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(
                                        CupertinoIcons.person_fill,
                                        color: Colors.white54,
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Name ──
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'You are Host Now! 🎉',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Divider ──
                          Divider(
                            color: Colors.white.withValues(alpha: 0.1),
                            thickness: 1,
                          ),

                          const SizedBox(height: 20),

                          // ── Host ID ──
                          Text(
                            'HOST ID',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hostId,
                            style: const TextStyle(
                              color: Color(0xFFFF6B9D),
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Cancel button ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _cancelApplication,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade400, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.red.shade400, strokeWidth: 2),
                          )
                        : Text(
                            'Cancel Host',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      },
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
            _buildTextField(
              controller: _idNumberController,
              label: 'Host ID (Auto-generated)',
              icon: CupertinoIcons.lock_fill,
              readOnly: true,
            ),
            const SizedBox(height: 20),
            _buildHostTypePicker(),
            const SizedBox(height: 20),
            _buildCountryPicker(),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _agencyCodeController,
              label: 'Agency Code',
              icon: CupertinoIcons.building_2_fill,
              validator: (v) => v!.isEmpty ? 'Agency Code is required' : null,
            ),
            const SizedBox(height: 30),
            Center(child: _buildImagePicker()),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: readOnly
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: readOnly
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.pink.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 18),
                child: Icon(
                  icon,
                  color: readOnly ? Colors.white38 : AppColors.pinkLight,
                  size: 20,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: keyboardType,
                  readOnly: readOnly,
                  style: TextStyle(
                    color: readOnly ? Colors.white54 : Colors.white,
                    letterSpacing: readOnly ? 1.5 : 0,
                    fontWeight:
                        readOnly ? FontWeight.w600 : FontWeight.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: label,
                    hintStyle:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(
                        left: 15, right: 20, top: 16, bottom: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHostTypePicker() {
    final hostTypes = ['Audio', 'Video', 'Both'];
    final Map<String, (IconData, Color)> details = {
      'Audio': (CupertinoIcons.music_mic, Colors.cyan),
      'Video': (CupertinoIcons.video_camera_solid, Colors.pink),
      'Both': (CupertinoIcons.speaker_2_fill, AppColors.pinkLight),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border:
                Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedHostType,
              isExpanded: true,
              hint: Row(children: [
                Icon(CupertinoIcons.star_fill,
                    color: AppColors.pinkLight, size: 20),
                const SizedBox(width: 15),
                Text('Select Host Type',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7))),
              ]),
              dropdownColor: Colors.grey[900],
              icon:
                  Icon(CupertinoIcons.chevron_down, color: AppColors.pinkLight),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              selectedItemBuilder: (ctx) => hostTypes.map<Widget>((v) {
                final d = details[v]!;
                return Row(children: [
                  Icon(d.$1, color: d.$2, size: 20),
                  const SizedBox(width: 15),
                  Text(v),
                ]);
              }).toList(),
              items: hostTypes.map((v) {
                final d = details[v]!;
                return DropdownMenuItem<String>(
                  value: v,
                  child: Row(children: [
                    Icon(d.$1, color: d.$2, size: 20),
                    const SizedBox(width: 15),
                    Text(v),
                  ]),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedHostType = v),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryPicker() {
    final countryText = _selectedCountryName ?? 'Select Location (Country)';
    final prefix = _selectedCountryFlagEmoji != null
        ? Text(_selectedCountryFlagEmoji!,
            style: const TextStyle(fontSize: 26))
        : Icon(CupertinoIcons.location_solid,
            color: AppColors.pinkLight, size: 20);

    return GestureDetector(
      onTap: () => showCountryPicker(
        context: context,
        showPhoneCode: false,
        onSelect: (c) => setState(() {
          _selectedCountryName = c.name;
          _selectedCountryFlagEmoji = c.flagEmoji;
        }),
        countryListTheme: CountryListThemeData(
          backgroundColor: Colors.grey[900],
          textStyle: const TextStyle(color: Colors.white),
          bottomSheetHeight: 500,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          inputDecoration: InputDecoration(
            labelText: 'Search',
            hintText: 'Start typing to search',
            labelStyle: TextStyle(color: AppColors.pinkLight),
            prefixIcon: Icon(Icons.search, color: AppColors.pinkLight),
            border: OutlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.pinkLight.withValues(alpha: 0.5))),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: AppColors.pinkLight.withValues(alpha: 0.5))),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: AppColors.pink)),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(children: [
              prefix,
              const SizedBox(width: 15),
              Expanded(
                child: Text(countryText,
                    style: TextStyle(
                        color: _selectedCountryName != null
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 16),
                    overflow: TextOverflow.ellipsis),
              ),
              Icon(CupertinoIcons.chevron_down,
                  color: AppColors.pinkLight, size: 20),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Column(
        children: [
          Container(
            height: 140,
            width: 160,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: _selfieImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(_selfieImage!, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.camera_fill,
                          color: AppColors.pinkLight, size: 44),
                      const SizedBox(height: 10),
                      const Text('Tap to upload',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          const Text('Selfie of Host',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _infoCard(String label, String value, IconData icon) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
                color: Colors.pink.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.pinkLight, size: 22),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _imageCard(String label, String url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  color: Colors.grey[800],
                  child: const Icon(Icons.broken_image, color: Colors.white38))),
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    } catch (_) {
      return 'N/A';
    }
  }
}
