import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/remote/firebase/profile_services.dart';
import '../../core/localization/app_localizations.dart';

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

  final _nameController = TextEditingController();
  final _whatsappController = TextEditingController();
  String? _profileImageUrl;
  File? _selectedImageFile;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
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
        _whatsappController.text = data['whatsappNumber'] ?? '';
        _profileImageUrl = data['photoUrl'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).errorLoadingProfile} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
        _profileImageUrl = null;
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
        whatsappNumber: _whatsappController.text,
        imageFile: _selectedImageFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).profileUpdatedSuccess)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).errorSavingProfile} $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            Container(
              color: const Color(0xFF5A189A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).editProfile,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isFetching
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF5A189A)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: _buildProfilePictureEditor()),
                            const SizedBox(height: 32),

                            // 1. Name Field
                            _buildFieldLabel(AppLocalizations.of(context).nameLabel),
                            const SizedBox(height: 8),
                            _buildLightTextField(
                              controller: _nameController,
                              hintText: AppLocalizations.of(context).nameLabel,
                              maxLength: 50,
                              validator: (value) => (value == null || value.isEmpty)
                                  ? AppLocalizations.of(context).nameEmptyError
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // 2. WhatsApp Number Field
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 16, color: Color(0xFF25D366)),
                                const SizedBox(width: 6),
                                _buildFieldLabel('WhatsApp Number'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildLightTextField(
                              controller: _whatsappController,
                              hintText: 'Enter your WhatsApp number',
                              maxLength: 20,
                            ),
                            const SizedBox(height: 36),

                            // Update Button
                            _buildUpdateButton(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
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
          width: 145,
          height: 145,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFF9800), width: 3.5),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(child: imageContent),
        ),
        Positioned(
          bottom: 4,
          right: 4,
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF5A189A),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D1B2A), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholderIcon() {
    return Container(
      color: const Color(0xFF512DA8),
      child: const Center(
        child: Text(
          't',
          style: TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLightTextField({
    required TextEditingController controller,
    required String hintText,
    int minLines = 1,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return StatefulBuilder(
      builder: (context, setStateField) {
        final currentLength = controller.text.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E42),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
              ),
              child: TextFormField(
                controller: controller,
                validator: validator,
                onChanged: (text) => setStateField(() {}),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                minLines: minLines,
                maxLines: maxLines,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  counterText: "",
                ),
              ),
            ),
            if (maxLength != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(
                  '$currentLength/$maxLength',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUpdateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5A189A),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Text(
                'Update',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
