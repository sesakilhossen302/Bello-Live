import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class NotificationNoticePage extends StatelessWidget {
  const NotificationNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F121B),
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              'নোটিশ ও ঘোষণা',
              style: GoogleFonts.hindSiliguri(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appSettings')
            .doc('notificationnotice')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading notices: ${snapshot.error}',
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          List<String> notices = [];
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();
            if (data != null) {
              final rawList = data['notification'] ?? data['notices'] ?? data['noticeList'];
              if (rawList is List) {
                notices = rawList
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              } else if (rawList is String && rawList.trim().isNotEmpty) {
                notices = [rawList.trim()];
              }
            }
          }

          // Show most recent notice at the top
          notices = notices.reversed.toList();

          if (notices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_off_outlined,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'বর্তমানে কোনো নোটিশ নেই',
                      style: GoogleFonts.hindSiliguri(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'নতুন ঘোষণা বা আপডেট আসলে এখানে প্রদর্শিত হবে।',
                      style: GoogleFonts.hindSiliguri(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notices.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final noticeText = notices[index];

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B202D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: index == 0
                        ? AppColors.primaryColor.withValues(alpha: 0.6)
                        : AppColors.primaryColor.withValues(alpha: 0.25),
                    width: index == 0 ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: index == 0
                          ? AppColors.primaryColor.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Top Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.campaign_rounded,
                              color: AppColors.primaryColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'নোটিশ #${index + 1}',
                            style: GoogleFonts.hindSiliguri(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (index == 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'নতুন',
                                style: GoogleFonts.hindSiliguri(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Copy button
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: noticeText));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF202636),
                                  content: Text(
                                    'নোটিশ টেক্সট কপি করা হয়েছে!',
                                    style: GoogleFonts.hindSiliguri(color: Colors.white),
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.copy_rounded, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'কপি',
                                    style: GoogleFonts.hindSiliguri(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    // Notice Body Text
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: SelectableText(
                        noticeText,
                        style: GoogleFonts.hindSiliguri(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 15,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
