// lib/presentation/profile/apply_hosting_page.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';

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
  String? _conflictingApplicationError;

  // Controllers
  final _idNumberController = TextEditingController();
  final _agencyCodeController = TextEditingController();

  // State variables
  String? _selectedHostType;
  String? _selectedCountryName;
  String? _selectedCountryFlagEmoji;

  // Removed _agencyCardImage
  File? _selfieImage;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    _agencyCodeController.dispose();
    super.dispose();
  }

  Future<void> _checkApplicationStatus() async {
    setState(() {
      _isCheckingStatus = true;
    });
    try {
      // 1. Check for its OWN application status first
      final statusDoc = await ProfileService.getHostingApplicationStatus();
      if (statusDoc.exists) {
        final data = statusDoc.data() as Map<String, dynamic>;
        setState(() {
          _applicationStatus = data['status'];
        });
      } else {
        // 2. If NO own application, check for a CONFLICTING (agency) application
        final agencyStatusDoc = await ProfileService.getAgencyApplicationStatus();
        if (agencyStatusDoc.exists) {
          setState(() {
            _conflictingApplicationError = "You have already applied for an agency. You cannot apply for hosting.";
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

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    // Updated check: only checking selfie now
    if (_selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload a selfie.')));
      return;
    }
    if (_selectedHostType == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a host type.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ProfileService.applyForHosting(
        idNumber: _idNumberController.text,
        hostType: _selectedHostType!,
        location: _selectedCountryName ?? 'N/A',
        locationFlag: _selectedCountryFlagEmoji,
        agencyCode: _agencyCodeController.text,
        // Pass string code
        selfieFile: _selfieImage!,
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully!')));
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting application: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                    ? _buildStatusDisplay()
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
      padding: EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: Offset(0, 2))],
            ),
          ),
          Spacer(),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
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
            Text(
              'Application Blocked',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _applicationStatus == 'pending' ? CupertinoIcons.clock_fill : CupertinoIcons.check_mark_circled_solid,
            color: _applicationStatus == 'pending' ? Colors.amber : Colors.green,
            size: 80,
          ),
          const SizedBox(height: 20),
          Text('Your application is ${_applicationStatus!}.', style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 10),
          Text('Admin will review your submission shortly.', style: TextStyle(color: Colors.white70, fontSize: 14)),
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
              controller: _idNumberController,
              label: 'ID Number',
              icon: CupertinoIcons.number,
              validator: (v) => v!.isEmpty ? 'ID Number is required' : null,
            ),
            const SizedBox(height: 20),
            _buildHostTypePicker(),
            const SizedBox(height: 20),
            _buildCountryPicker(),
            const SizedBox(height: 20),

            // REPLACED IMAGE PICKER WITH TEXT FIELD
            _buildGlassyTextField(
              controller: _agencyCodeController,
              label: 'Agency Code',
              icon: CupertinoIcons.building_2_fill,
              validator: (v) => v!.isEmpty ? 'Agency Code is required' : null,
            ),
            const SizedBox(height: 30),

            // CENTERED SELFIE PICKER (As it's now alone)
            Center(
              child: _buildImagePicker(
                label: 'Selfie of Host',
                imageFile: _selfieImage,
                onTap: () => _pickImage(ImageSource.camera, (file) => _selfieImage = file),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Reusable Widgets ---

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
                  style: TextStyle(color: Colors.white),
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

  Widget _buildHostTypePicker() {
    final hostTypes = ['Audio', 'Video', 'Both'];
    final Map<String, (IconData, Color)> typeDetails = {
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
            border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedHostType,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(CupertinoIcons.star_fill, color: AppColors.pinkLight, size: 20),
                  SizedBox(width: 15),
                  Text('Select Host Type', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              dropdownColor: Colors.grey[900],
              icon: Icon(CupertinoIcons.chevron_down, color: AppColors.pinkLight),
              style: TextStyle(color: Colors.white, fontSize: 16),
              selectedItemBuilder: (BuildContext context) {
                return hostTypes.map<Widget>((String value) {
                  final details = typeDetails[value]!;
                  return Row(
                    children: [
                      Icon(details.$1, color: details.$2, size: 20),
                      SizedBox(width: 15),
                      Text(value),
                    ],
                  );
                }).toList();
              },
              items: hostTypes.map((String value) {
                final details = typeDetails[value]!;
                return DropdownMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      Icon(details.$1, color: details.$2, size: 20),
                      SizedBox(width: 15),
                      Text(value),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedHostType = newValue;
                });
              },
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
                      Text('Tap to upload', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
