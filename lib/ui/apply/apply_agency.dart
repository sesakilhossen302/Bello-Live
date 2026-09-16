import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';

import '../../data/remote/firebase/profile_services.dart';

class ApplyAgencyPage extends StatefulWidget {
  const ApplyAgencyPage({super.key});

  @override
  State<ApplyAgencyPage> createState() => _ApplyAgencyPageState();
}

class _ApplyAgencyPageState extends State<ApplyAgencyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  String? _applicationStatus;
  Map<String, dynamic>? _applicationData;
  String? _conflictingApplicationError;

  final _agencyNameController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _referenceController = TextEditingController();

  String? _selectedCountryName;
  String? _selectedCountryFlagEmoji;
  File? _nidFrontImage;
  File? _nidBackImage;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  @override
  void dispose() {
    _agencyNameController.dispose();
    _holderNameController.dispose();
    _whatsappController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _checkApplicationStatus() async {
    setState(() => _isCheckingStatus = true);
    try {
      final statusDoc = await ProfileService.getAgencyApplicationStatus();
      if (statusDoc.exists) {
        final data = statusDoc.data() as Map<String, dynamic>;
        setState(() {
          _applicationStatus = data['status'];
          _applicationData = data;
        });
      }
    } catch (e) {
      debugPrint('Error checking agency status: $e');
    } finally {
      setState(() => _isCheckingStatus = false);
    }
  }

  Future<void> _pickImage(ImageSource source, Function(File) onImageSelected) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        onImageSelected(File(pickedFile.path));
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    if (_nidFrontImage == null || _nidBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both NID front and back images')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ProfileService.applyForAgency(
        agencyName: _agencyNameController.text.trim(),
        holderName: _holderNameController.text.trim(),
        location: _selectedCountryName ?? 'N/A',
        locationFlag: _selectedCountryFlagEmoji,
        whatsappNumber: _whatsappController.text.trim(),
        reference: _referenceController.text.trim(),
        nidFrontFile: _nidFrontImage!,
        nidBackFile: _nidBackImage!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agency application submitted successfully!'),
            backgroundColor: Color(0xFFE62563),
          ),
        );
        _checkApplicationStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelApplication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Application', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to cancel your agency application?',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ProfileService.cancelAgencyApplication();
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
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reApplyApplication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Re-apply for Agency', style: TextStyle(color: Color(0xFF1C1C1E), fontWeight: FontWeight.bold)),
        content: const Text(
          'Your previous application will be deleted and you can submit a new one. Continue?',
          style: TextStyle(color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue', style: TextStyle(color: Color(0xFFE62563), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ProfileService.cancelAgencyApplication();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091433),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isCheckingStatus
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE62563)))
                  : _conflictingApplicationError != null
                      ? _buildErrorDisplay(_conflictingApplicationError!)
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
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFFE62563),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          const Text(
            'Apply for Agency',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else if (_applicationStatus == null && _conflictingApplicationError == null)
            TextButton(
              onPressed: _submitApplication,
              child: const Text(
                'Submit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            Icon(CupertinoIcons.xmark_octagon_fill, color: Colors.red.shade400, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Application Blocked',
              style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedDisplay() {
    final data = _applicationData;
    final String agencyCode = (data?['agencyCode'] ?? 'N/A').toString();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE62563),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.checkmark_seal_fill, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Approved Agency',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                data?['agencyName'] ?? 'Agency',
                style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('You are an Agency Now! 🎉', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'AGENCY CODE',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              Text(
                agencyCode,
                style: const TextStyle(color: Color(0xFFE62563), fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingDisplay() {
    if (_applicationData == null) return const SizedBox();
    final data = _applicationData!;
    final submittedDate = _formatDate(data['submittedAt']);
    final country = data['location'] ?? data['countryName'] ?? 'N/A';
    final flag = (data['locationFlag'] ?? data['countryFlag']) as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          const Icon(CupertinoIcons.clock_fill, color: Colors.amber, size: 70),
          const SizedBox(height: 16),
          const Text(
            'Application Pending',
            style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your agency application is under review by admin',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _infoCard('Agency Name', data['agencyName'] ?? 'N/A', CupertinoIcons.building_2_fill),
          const SizedBox(height: 12),
          _infoCard('Holder Name', data['holderName'] ?? 'N/A', CupertinoIcons.person_fill),
          const SizedBox(height: 12),
          _infoCard('Country', flag != null ? '$flag $country' : country, CupertinoIcons.location_solid),
          const SizedBox(height: 12),
          _infoCard('WhatsApp', data['whatsappNumber'] ?? 'N/A', CupertinoIcons.phone_fill),
          const SizedBox(height: 12),
          _infoCard('Submitted On', submittedDate, CupertinoIcons.calendar),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _cancelApplication,
              icon: const Icon(CupertinoIcons.xmark_circle),
              label: const Text('Cancel Application'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildRejectedDisplay() {
    if (_applicationData == null) return const SizedBox();
    final data = _applicationData!;
    final reason = data['rejectionReason'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red.shade400, size: 70),
          const SizedBox(height: 16),
          const Text(
            'Application Rejected',
            style: TextStyle(color: Color(0xFF1C1C1E), fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your agency application was rejected by admin',
            style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.info_circle_fill, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rejection Reason',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(reason, style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _reApplyApplication,
              icon: const Icon(CupertinoIcons.arrow_clockwise),
              label: const Text('Re-apply for Agency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE62563),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _agencyNameController,
              label: 'Agency Name',
              icon: CupertinoIcons.building_2_fill,
              validator: (v) => v == null || v.trim().isEmpty ? 'Agency name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _holderNameController,
              label: 'Holder Name',
              icon: CupertinoIcons.person_fill,
              validator: (v) => v == null || v.trim().isEmpty ? 'Holder name is required' : null,
            ),
            const SizedBox(height: 16),
            _buildCountryPicker(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number',
              icon: CupertinoIcons.phone_fill,
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.trim().isEmpty ? 'WhatsApp number is required' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _referenceController,
              label: 'Reference Code (Optional)',
              icon: CupertinoIcons.ticket_fill,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildNidCard(
                    title: 'NID Front',
                    image: _nidFrontImage,
                    onTap: () => _pickImage(ImageSource.gallery, (file) => _nidFrontImage = file),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildNidCard(
                    title: 'NID Back',
                    image: _nidBackImage,
                    onTap: () => _pickImage(ImageSource.gallery, (file) => _nidBackImage = file),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Icon(icon, color: const Color(0xFFE62563), size: 20),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              validator: validator,
              keyboardType: keyboardType,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryPicker() {
    final countryText = _selectedCountryName ?? 'Select Country';
    final prefix = _selectedCountryFlagEmoji != null
        ? Text(_selectedCountryFlagEmoji!, style: const TextStyle(fontSize: 24))
        : const Icon(CupertinoIcons.location_solid, color: Color(0xFFE62563), size: 20);

    return GestureDetector(
      onTap: () => showCountryPicker(
        context: context,
        showPhoneCode: false,
        onSelect: (c) => setState(() {
          _selectedCountryName = c.name;
          _selectedCountryFlagEmoji = c.flagEmoji;
        }),
        countryListTheme: CountryListThemeData(
          backgroundColor: Colors.white,
          textStyle: const TextStyle(color: Color(0xFF1C1C1E)),
          bottomSheetHeight: 500,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          inputDecoration: const InputDecoration(
            labelText: 'Search',
            hintText: 'Start typing to search',
            labelStyle: TextStyle(color: Color(0xFFE62563)),
            prefixIcon: Icon(Icons.search, color: Color(0xFFE62563)),
            border: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE62563))),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE62563))),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFE62563))),
          ),
        ),
      ),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E42),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            prefix,
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                countryText,
                style: TextStyle(
                  color: _selectedCountryName != null ? Colors.white : Colors.white38,
                  fontSize: 15,
                  fontWeight: _selectedCountryName != null ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(CupertinoIcons.chevron_down, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildNidCard({
    required String title,
    required File? image,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E42),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(image, fit: BoxFit.cover, width: double.infinity),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.camera_fill, color: Color(0xFFE62563), size: 36),
                      SizedBox(height: 6),
                      Text(
                        'Upload Image',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE62563), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
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
