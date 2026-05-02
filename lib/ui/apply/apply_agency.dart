import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:intl/intl.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../theme/app_theme.dart';

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

  // State for conflicting application
  String? _conflictingApplicationError;

  // Controllers
  final _agencyNameController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _referenceController = TextEditingController();

  // State variables
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
    setState(() {
      _isCheckingStatus = true;
    });
    try {
      final statusDoc = await ProfileService.getAgencyApplicationStatus();
      if (statusDoc.exists) {
        final data = statusDoc.data() as Map<String, dynamic>;
        setState(() {
          _applicationStatus = data['status'];
          _applicationData = data;
        });
      } else {
        final hostingStatusDoc = await ProfileService.getHostingApplicationStatus();
        if (hostingStatusDoc.exists) {
          setState(() {
            _conflictingApplicationError = "You have already applied for hosting. You cannot apply for an agency.";
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking status: $e");
    } finally {
      setState(() {
        _isCheckingStatus = false;
      });
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

  // Clear form and reset state
  void _clearForm() {
    _formKey.currentState?.reset();
    _agencyNameController.clear();
    _holderNameController.clear();
    _whatsappController.clear();
    _referenceController.clear();
    setState(() {
      _selectedCountryName = null;
      _selectedCountryFlagEmoji = null;
      _nidFrontImage = null;
      _nidBackImage = null;
    });
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    if (_nidFrontImage == null || _nidBackImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload both NID images.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ProfileService.applyForAgency(
        agencyName: _agencyNameController.text,
        holderName: _holderNameController.text,
        whatsappNumber: _whatsappController.text,
        location: _selectedCountryName ?? 'N/A',
        locationFlag: _selectedCountryFlagEmoji,
        reference: _referenceController.text,
        nidFrontFile: _nidFrontImage!,
        nidBackFile: _nidBackImage!,
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully!')));
      if (mounted) {
        _clearForm();
        _checkApplicationStatus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting application: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelApplication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Cancel Application', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to cancel your agency application?',
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
        await ProfileService.cancelAgencyApplication();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application cancelled successfully')));
        if (mounted) {
          setState(() {
            _applicationStatus = null;
            _applicationData = null;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cancelling application: $e')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // NEW: Handle re-apply action for rejected applications
  Future<void> _reApplyApplication() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Re-apply for Agency', style: TextStyle(color: Colors.white)),
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
      setState(() {
        _isLoading = true;
      });

      try {
        await ProfileService.cancelAgencyApplication();
        if (mounted) {
          setState(() {
            _applicationStatus = null;
            _applicationData = null;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('You can now submit a new application')));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
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
                    ? Center(child: CircularProgressIndicator(color: AppColors.pink))
                    : _conflictingApplicationError != null
                    ? _buildErrorDisplay(_conflictingApplicationError!)
                    : _applicationStatus != null
                    ? (_applicationStatus == 'accept'
                          ? _buildApprovedDisplay()
                          : _applicationStatus == 'reject'
                          ? _buildRejectedDisplay()
                          : _buildPendingDisplay())
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
      padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            'Apply for Agency',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))],
            ),
          ),
          const Spacer(),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 12.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: AppColors.pink, strokeWidth: 2),
              ),
            )
          else if (_applicationStatus == null && _conflictingApplicationError == null)
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

  Widget _buildErrorDisplay(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.xmark_octagon_fill, color: Colors.red.shade400, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Application Blocked',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingDisplay() {
    if (_applicationData == null) return const SizedBox();

    final String agencyName = _applicationData!['agencyName'] ?? 'N/A';
    final String holderName = _applicationData!['holderName'] ?? 'N/A';
    final String email = _applicationData!['email'] ?? 'N/A';
    final String whatsappNumber = _applicationData!['whatsappNumber'] ?? 'N/A';
    final String location = _applicationData!['location'] ?? 'N/A';
    final String? locationFlag = _applicationData!['locationFlag'];
    final String reference = _applicationData!['reference'] ?? 'N/A';
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
          const SizedBox(height: 20),
          Icon(CupertinoIcons.clock_fill, color: Colors.amber, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Application Pending',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your agency application is under review',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildInfoCard('Agency Name', agencyName, CupertinoIcons.building_2_fill),
          const SizedBox(height: 15),
          _buildInfoCard('Holder Name', holderName, CupertinoIcons.person_fill),
          const SizedBox(height: 15),
          _buildInfoCard('Email', email, CupertinoIcons.mail_solid),
          const SizedBox(height: 15),
          _buildInfoCard('WhatsApp Number', whatsappNumber, Icons.message),
          const SizedBox(height: 15),
          _buildInfoCard(
            'Location',
            locationFlag != null ? '$locationFlag $location' : location,
            CupertinoIcons.location_solid,
          ),
          const SizedBox(height: 15),
          _buildInfoCard('Reference', reference, CupertinoIcons.group_solid),
          const SizedBox(height: 15),
          _buildInfoCard('Submitted On', submittedDate, CupertinoIcons.calendar),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _cancelApplication,
            icon: const Icon(CupertinoIcons.xmark_circle_fill),
            label: const Text('Cancel Application'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
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

  // NEW: Build rejected display with reason and re-apply option
  Widget _buildRejectedDisplay() {
    if (_applicationData == null) return const SizedBox();

    final String agencyName = _applicationData!['agencyName'] ?? 'N/A';
    final String holderName = _applicationData!['holderName'] ?? 'N/A';
    final String email = _applicationData!['email'] ?? 'N/A';
    final String whatsappNumber = _applicationData!['whatsappNumber'] ?? 'N/A';
    final String location = _applicationData!['location'] ?? 'N/A';
    final String? locationFlag = _applicationData!['locationFlag'];
    final String reference = _applicationData!['reference'] ?? 'N/A';
    final String? reason = _applicationData!['reason'];
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
          const SizedBox(height: 20),
          Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red.shade400, size: 80),
          const SizedBox(height: 20),
          const Text(
            'Application Rejected',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your agency application was not approved',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),

          // Show rejection reason if available
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
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(CupertinoIcons.info_circle_fill, color: Colors.red.shade300, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Rejection Reason',
                            style: TextStyle(color: Colors.red.shade300, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(reason, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 30),
          const Text(
            'Your Previous Application Details',
            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildInfoCard('Agency Name', agencyName, CupertinoIcons.building_2_fill),
          const SizedBox(height: 15),
          _buildInfoCard('Holder Name', holderName, CupertinoIcons.person_fill),
          const SizedBox(height: 15),
          _buildInfoCard('Email', email, CupertinoIcons.mail_solid),
          const SizedBox(height: 15),
          _buildInfoCard('WhatsApp Number', whatsappNumber, Icons.message),
          const SizedBox(height: 15),
          _buildInfoCard(
            'Location',
            locationFlag != null ? '$locationFlag $location' : location,
            CupertinoIcons.location_solid,
          ),
          const SizedBox(height: 15),
          _buildInfoCard('Reference', reference, CupertinoIcons.group_solid),
          const SizedBox(height: 15),
          _buildInfoCard('Submitted On', submittedDate, CupertinoIcons.calendar),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _reApplyApplication,
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.check_mark_circled_solid, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Congratulations!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'You are now an agency',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please visit the agency portal to manage your agency',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () async {
                final Uri url = Uri.parse('https://picture-live-mother-portal.web.app');

                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication, // Opens in default browser
                    );
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Could not open the agency portal')));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening portal: $e')));
                  }
                }
              },
              icon: const Icon(CupertinoIcons.arrow_right_circle_fill),
              label: const Text('Go to Agency Portal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
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

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildGlassyTextField(
              controller: _agencyNameController,
              label: 'Agency Name',
              icon: CupertinoIcons.building_2_fill,
              validator: (v) => v!.isEmpty ? 'Agency Name is required' : null,
            ),
            const SizedBox(height: 20),
            _buildGlassyTextField(
              controller: _holderNameController,
              label: 'Holder Name',
              icon: CupertinoIcons.person_fill,
              validator: (v) => v!.isEmpty ? 'Holder Name is required' : null,
            ),
            const SizedBox(height: 20),
            _buildGlassyTextField(
              controller: _whatsappController,
              label: 'WhatsApp Number',
              icon: Icons.message,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'WhatsApp number is required' : null,
            ),
            const SizedBox(height: 20),
            _buildCountryPicker(),
            const SizedBox(height: 20),
            _buildGlassyTextField(
              controller: _referenceController,
              label: 'Reference (Optional)',
              icon: CupertinoIcons.group_solid,
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildImagePicker(
                  label: 'NID Front',
                  imageFile: _nidFrontImage,
                  onTap: () => _pickImage(ImageSource.gallery, (file) => _nidFrontImage = file),
                ),
                _buildImagePicker(
                  label: 'NID Back',
                  imageFile: _nidBackImage,
                  onTap: () => _pickImage(ImageSource.gallery, (file) => _nidBackImage = file),
                ),
              ],
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
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 18),
                child: Icon(icon, color: AppColors.pinkLight, size: 20),
              ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  validator: validator,
                  style: const TextStyle(color: Colors.white),
                  minLines: minLines,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  keyboardType: keyboardType,
                  decoration: InputDecoration(
                    hintText: label,
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(left: 15, right: 20, top: 16, bottom: 16),
                    counterText: "",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryPicker() {
    String countryText = _selectedCountryName ?? 'Select Location (Country)';
    Widget prefixWidget = _selectedCountryFlagEmoji != null
        ? Text(_selectedCountryFlagEmoji!, style: const TextStyle(fontSize: 26))
        : Icon(CupertinoIcons.location_solid, color: AppColors.pinkLight, size: 20);

    return GestureDetector(
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: false,
          onSelect: (Country country) {
            setState(() {
              _selectedCountryName = country.name;
              _selectedCountryFlagEmoji = country.flagEmoji;
            });
          },
          countryListTheme: CountryListThemeData(
            backgroundColor: Colors.grey[900],
            textStyle: const TextStyle(color: Colors.white),
            bottomSheetHeight: 500,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20.0), topRight: Radius.circular(20.0)),
            inputDecoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Start typing to search',
              labelStyle: TextStyle(color: AppColors.pinkLight),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              prefixIcon: Icon(Icons.search, color: AppColors.pinkLight),
              border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.pinkLight.withValues(alpha: 0.5))),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.pinkLight.withValues(alpha: 0.5))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.pink)),
            ),
          ),
        );
      },
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
              border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                prefixWidget,
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    countryText,
                    style: TextStyle(
                      color: _selectedCountryName != null ? Colors.white : Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(CupertinoIcons.chevron_down, color: AppColors.pinkLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker({required String label, File? imageFile, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 120,
            width: 150,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(imageFile, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.camera_fill, color: AppColors.pinkLight, size: 40),
                      const SizedBox(height: 8),
                      const Text('Tap to upload', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
