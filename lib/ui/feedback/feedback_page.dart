import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';

import '../../theme/app_theme.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with TickerProviderStateMixin {
  late TabController _tabController;

  // Feedback form variables
  String selectedFeedbackType = '';
  String selectedContactType = 'email';
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  File? _selectedFile;

  // final ImagePicker _picker = ImagePicker();

  // Dummy feedback data for "My Feedback" tab
  final List<FeedbackItem> _myFeedbackList = [
    FeedbackItem(
      type: 'App Error',
      message: 'The app crashes when I try to open the store page...',
      status: 'Resolved',
      date: DateTime.now().subtract(const Duration(days: 2)),
      response: 'Thank you for reporting this issue. We have fixed the bug in the latest update.',
    ),
    FeedbackItem(
      type: 'Suggestions',
      message: 'It would be great if you could add dark mode to the app...',
      status: 'In Progress',
      date: DateTime.now().subtract(const Duration(days: 5)),
      response: 'We appreciate your suggestion and are currently working on implementing dark mode.',
    ),
    FeedbackItem(
      type: 'Earning Info',
      message: 'I have questions about how the earning system works...',
      status: 'Pending',
      date: DateTime.now().subtract(const Duration(days: 7)),
      response: null,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _contactController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.pink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'Feedback',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Tab Bar
              _buildTabBar(),

              // Tab Views
              Expanded(
                child: TabBarView(controller: _tabController, children: [_buildFeedbackTab(), _buildMyFeedbackTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600]),
              boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 0))],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(text: 'Feedback'),
              Tab(text: 'My Feedback'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Feedback Type Selection
          _buildSectionTitle('Feedback Type'),
          const SizedBox(height: 15),
          _buildFeedbackTypeButtons(),

          const SizedBox(height: 30),

          // Contact Information
          _buildSectionTitle('Contact Information'),
          const SizedBox(height: 15),
          _buildContactTypeSelection(),

          const SizedBox(height: 20),
          _buildContactField(),

          const SizedBox(height: 30),

          // Feedback Message
          _buildSectionTitle('Your Feedback'),
          const SizedBox(height: 15),
          _buildFeedbackField(),

          const SizedBox(height: 30),

          // File Upload
          _buildSectionTitle('Attach File (Optional)'),
          const SizedBox(height: 15),
          _buildFileUploadSection(),

          const SizedBox(height: 40),

          // Submit Button
          _buildSubmitButton(),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildMyFeedbackTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ..._myFeedbackList.map((feedback) => _buildFeedbackItem(feedback)),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 5, offset: const Offset(0, 1))],
      ),
    );
  }

  Widget _buildFeedbackTypeButtons() {
    final feedbackTypes = ['App Error', 'Suggestions', 'Earning Info', 'Other'];
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.purple];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: feedbackTypes.asMap().entries.map((entry) {
        int index = entry.key;
        String type = entry.value;
        bool isSelected = selectedFeedbackType == type;

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedFeedbackType = type;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: isSelected ? colors[index].withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: isSelected ? colors[index] : Colors.white.withValues(alpha: 0.3), width: 1.5),
              boxShadow: isSelected
                  ? [BoxShadow(color: colors[index].withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? colors[index] : Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContactTypeSelection() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedContactType = 'email';
                _contactController.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: selectedContactType == 'email' ? Colors.pink.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.3),
                border: Border.all(
                  color: selectedContactType == 'email' ? Colors.pink : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
                boxShadow: selectedContactType == 'email'
                    ? [BoxShadow(color: Colors.pink.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.email_rounded,
                        color: selectedContactType == 'email' ? Colors.pink : Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Email',
                        style: TextStyle(
                          color: selectedContactType == 'email' ? Colors.pink : Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedContactType = 'phone';
                _contactController.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: selectedContactType == 'phone' ? Colors.blue.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3),
                border: Border.all(
                  color: selectedContactType == 'phone' ? Colors.blue : Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: selectedContactType == 'phone'
                    ? [BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.phone_rounded,
                        color: selectedContactType == 'phone' ? Colors.blue : Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Phone',
                        style: TextStyle(
                          color: selectedContactType == 'phone' ? Colors.blue : Colors.white.withValues(alpha: 0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: _contactController,
            keyboardType: selectedContactType == 'email' ? TextInputType.emailAddress : TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: selectedContactType == 'email' ? 'Enter your email address' : 'Enter your phone number',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon: Icon(
                selectedContactType == 'email' ? Icons.email_outlined : Icons.phone_outlined,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TextField(
            controller: _feedbackController,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Please describe your feedback in detail...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileUploadSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_selectedFile == null) ...[
                  Icon(Icons.cloud_upload_outlined, color: Colors.white.withValues(alpha: 0.7), size: 40),
                  const SizedBox(height: 10),
                  Text(
                    'Upload Image or Video',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildUploadButton('Image', Icons.image_rounded, Colors.purple, () => _pickFile()),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildUploadButton('Video', Icons.videocam_rounded, Colors.orange, () => _pickVideo()),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      Icon(
                        _selectedFile!.path.contains('.mp4') ? Icons.videocam_rounded : Icons.image_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _selectedFile!.path.split('/').last,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedFile = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.2),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    bool isFormValid =
        selectedFeedbackType.isNotEmpty && _contactController.text.isNotEmpty && _feedbackController.text.isNotEmpty;

    return GestureDetector(
      onTap: isFormValid ? _submitFeedback : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: isFormValid
              ? LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600])
              : LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700]),
          boxShadow: isFormValid
              ? [BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))]
              : null,
        ),
        child: Center(
          child: Text(
            'Submit Feedback',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackItem(FeedbackItem feedback) {
    Color statusColor = _getStatusColor(feedback.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _getFeedbackTypeColor(feedback.type).withValues(alpha: 0.2),
                      border: Border.all(color: _getFeedbackTypeColor(feedback.type).withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      feedback.type,
                      style: TextStyle(
                        color: _getFeedbackTypeColor(feedback.type),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: statusColor.withValues(alpha: 0.2),
                      border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Text(
                      feedback.status,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Text(
                feedback.message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),

              if (feedback.response != null) ...[
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.green.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.support_agent_rounded, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Response',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feedback.response!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 15),

              Text(
                _formatDate(feedback.date),
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Resolved':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getFeedbackTypeColor(String type) {
    switch (type) {
      case 'App Error':
        return Colors.red;
      case 'Suggestions':
        return Colors.blue;
      case 'Earning Info':
        return Colors.green;
      case 'Other':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _pickFile() async {
    // final XFile? file = await _picker.pickImage(source: source);
    // if (file != null) {
    //   setState(() {
    //     _selectedFile = File(file.path);
    //   });
    // }
  }

  Future<void> _pickVideo() async {
    // final XFile  file = await _picker.pickVideo(source: ImageSource.gallery);
    // if (file != null) {
    //   setState(() {
    //     _selectedFile = File(file.path);
    //   });
    // }
  }

  void _submitFeedback() {
    // Handle feedback submission logic here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Feedback submitted successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Clear form
    setState(() {
      selectedFeedbackType = '';
      selectedContactType = 'email';
      _contactController.clear();
      _feedbackController.clear();
      _selectedFile = null;
    });
  }
}

// Data Models
class FeedbackItem {
  final String type;
  final String message;
  final String status;
  final DateTime date;
  final String? response;

  FeedbackItem({required this.type, required this.message, required this.status, required this.date, this.response});
}
