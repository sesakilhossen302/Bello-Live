import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// New Import
import 'package:country_picker/country_picker.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../theme/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  String? _userId;
  bool _isLoading = false;
  bool _isFetching = true;

  // Controllers
  final _nameController = TextEditingController();

  // final _countryController = TextEditingController(); // Removed
  final _bioController = TextEditingController();

  // State variables
  String? _selectedGender;
  DateTime? _selectedDob;
  String? _profileImageUrl;
  File? _selectedImageFile;
  int _bioCharCount = 0;

  // New state variables for country
  String? _selectedCountryName;
  String? _selectedCountryFlagEmoji;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _bioController.addListener(_updateBioCount);
    _loadCurrentProfile();
  }

  void _updateBioCount() {
    if (_bioController.text.length <= 80) {
      setState(() {
        _bioCharCount = _bioController.text.length;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    // _countryController.dispose(); // Removed
    _bioController.removeListener(_updateBioCount);
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentProfile() async {
    if (_userId == null) {
      setState(() {
        _isFetching = false;
      });
      return;
    }
    try {
      final doc = await ProfileService.getUserProfile(_userId!);
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _nameController.text = data['displayName'] ?? '';

        // Updated logic for country
        _selectedCountryName = data['country'];
        _selectedCountryFlagEmoji = data['countryFlagEmoji']; // Assumes you store this

        _bioController.text = data['bio'] ?? '';
        _selectedGender = data['gender'];
        _profileImageUrl = data['photoUrl'];
        if (data['dob'] != null) {
          _selectedDob = (data['dob'] as Timestamp).toDate();
        }
        setState(() {
          _bioCharCount = _bioController.text.length;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
        _profileImageUrl = null; // Clear network image to show file image
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ProfileService.updateUserProfile(
        displayName: _nameController.text,
        country: _selectedCountryName,
        countryFlagEmoji: _selectedCountryFlagEmoji,
        bio: _bioController.text,
        gender: _selectedGender,
        dob: _selectedDob,
        imageFile: _selectedImageFile,
      );

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
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
              // Header Section
              Padding(
                padding: EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(CupertinoIcons.back, size: 28, color: AppColors.pink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: Offset(0, 2))],
                      ),
                    ),
                    Spacer(),
                    _isLoading
                        ? Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: AppColors.pink, strokeWidth: 2),
                            ),
                          )
                        : TextButton(
                            onPressed: _saveProfile,
                            child: Text(
                              'Save',
                              style: TextStyle(color: AppColors.pink, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ],
                ),
              ),
              Expanded(
                child: _isFetching
                    ? Center(child: CircularProgressIndicator(color: AppColors.pink))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              _buildProfilePictureEditor(),
                              const SizedBox(height: 30),
                              _buildGlassyTextField(
                                controller: _nameController,
                                label: 'Name',
                                icon: CupertinoIcons.person_fill,
                                validator: (value) => (value == null || value.isEmpty) ? 'Name cannot be empty' : null,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 20),
                              _buildGenderPicker(),
                              const SizedBox(height: 20),
                              _buildDobPicker(),
                              const SizedBox(height: 20),

                              // Replaced TextField with Country Picker
                              _buildCountryPicker(),

                              const SizedBox(height: 20),
                              _buildGlassyTextField(
                                controller: _bioController,
                                label: 'Bio',
                                icon: CupertinoIcons.book_fill,
                                minLines: 2,
                                maxLines: 4,
                                maxLength: 80,
                                currentCharCount: _bioCharCount,
                                displayMaxLength: 80,
                              ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureEditor() {
    Widget imageContent;
    if (_selectedImageFile != null) {
      imageContent = Image.file(_selectedImageFile!, fit: BoxFit.cover);
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      imageContent = Image.network(
        _profileImageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderIcon(),
      );
    } else {
      imageContent = _placeholderIcon();
    }

    return Stack(
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [AppColors.pinkLight, AppColors.pinkDark]),
          ),
          padding: const EdgeInsets.all(4),
          child: ClipOval(child: imageContent),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.pink,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.5), width: 2),
              ),
              child: Icon(CupertinoIcons.pencil, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholderIcon() {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade800])),
      child: const Icon(Icons.person, color: Colors.white, size: 70),
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
    int? currentCharCount,
    int? displayMaxLength,
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
          child: Column(
            children: [
              Row(
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
              Visibility(
                visible: displayMaxLength != null && currentCharCount != null,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$currentCharCount/$displayMaxLength',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // New Widget: Country Picker
  Widget _buildCountryPicker() {
    String countryText = _selectedCountryName ?? 'Select Location (Country)';

    // Use the flag emoji if it exists, otherwise use the location icon
    Widget prefixWidget = _selectedCountryFlagEmoji != null
        ? Text(_selectedCountryFlagEmoji!, style: const TextStyle(fontSize: 26))
        : Icon(CupertinoIcons.location_solid, color: AppColors.pinkLight, size: 20);

    return GestureDetector(
      onTap: () {
        showCountryPicker(
          context: context,
          showPhoneCode: false, // Don't show phone code
          onSelect: (Country country) {
            setState(() {
              _selectedCountryName = country.name;
              _selectedCountryFlagEmoji = country.flagEmoji;
            });
          },
          // Style the picker to match your app's theme
          countryListTheme: CountryListThemeData(
            backgroundColor: Colors.grey[900],
            textStyle: const TextStyle(color: Colors.white),
            bottomSheetHeight: 500,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20.0), topRight: Radius.circular(20.0)),
            // Style the search field
            inputDecoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Start typing to search',
              labelStyle: TextStyle(color: AppColors.pinkLight),
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              prefixIcon: Icon(Icons.search, color: AppColors.pinkLight),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.pinkLight.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(15),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.pinkLight.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(15),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.pink),
                borderRadius: BorderRadius.circular(15),
              ),
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
                prefixWidget, // Your new flag/icon widget
                const SizedBox(width: 15),
                // Expanded ensures text truncates nicely
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

  Widget _buildGenderPicker() {
    final genders = ['Male', 'Female', 'Other', 'Prefer not to say'];

    // 2. Define the icon and color mapping
    final Map<String, (IconData, Color)> genderDetails = {
      'Male': (Icons.male, Colors.blue.shade400),
      'Female': (Icons.female, Colors.pink.shade400),
      'Other': (Icons.transgender, AppColors.pinkLight),
      'Prefer not to say': (CupertinoIcons.question_circle, Colors.grey.shade400),
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
              value: _selectedGender,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(CupertinoIcons.heart_fill, color: AppColors.pinkLight, size: 20),
                  SizedBox(width: 15),
                  Text('Select Gender', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              dropdownColor: Colors.grey[900],
              icon: Icon(CupertinoIcons.chevron_down, color: AppColors.pinkLight),
              style: TextStyle(color: Colors.white, fontSize: 16),

              // 3. This builds the CLOSED button view when an item is selected
              selectedItemBuilder: (BuildContext context) {
                return genders.map<Widget>((String value) {
                  final details = genderDetails[value]!;
                  return Row(
                    children: [
                      Icon(details.$1, color: details.$2, size: 20),
                      SizedBox(width: 15),
                      Text(value),
                    ],
                  );
                }).toList();
              },

              // 4. This builds the OPEN dropdown list
              items: genders.map((String value) {
                final details = genderDetails[value]!;
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
                  _selectedGender = newValue;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDobPicker() {
    String dobText = _selectedDob != null ? DateFormat('MMMM d, yyyy').format(_selectedDob!) : 'Select Date of Birth';

    return GestureDetector(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: _selectedDob ?? DateTime(2000, 1, 1),
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
        );
        if (pickedDate != null) {
          setState(() {
            _selectedDob = pickedDate;
          });
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.gift_fill, color: AppColors.pinkLight, size: 20),
                SizedBox(width: 15),
                Text(
                  dobText,
                  style: TextStyle(
                    color: _selectedDob != null ? Colors.white : Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Icon(CupertinoIcons.calendar, color: AppColors.pinkLight, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
