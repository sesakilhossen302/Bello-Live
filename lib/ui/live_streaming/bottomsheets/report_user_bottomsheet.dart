import 'package:flutter/material.dart';

class ReportUserBottomSheet extends StatelessWidget {
  final String reportedUserId;
  final String reportedUserName;

  const ReportUserBottomSheet({super.key, required this.reportedUserId, required this.reportedUserName});

  @override
  Widget build(BuildContext context) {
    // Helper to create list tiles
    Widget buildOptionTile(String title) {
      return ListTile(
        // --- MODIFIED: Wrapped Text in a Center widget ---
        title: Center(
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
        onTap: () {
          // TODO: Implement actual report logic
          debugPrint('Reporting $reportedUserName ($reportedUserId) for: $title');
          Navigator.of(context).pop(); // Close the sheet
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you.'), backgroundColor: Colors.green));
        },
      );
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Report $reportedUserName',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          buildOptionTile('Pornography'),
          buildOptionTile('Sensitive content'),
          buildOptionTile('Drug-related content'),
          buildOptionTile('Other'),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            // --- MODIFIED: Wrapped Text in a Center widget ---
            title: const Center(
              child: Text('Cancel', style: TextStyle(color: Colors.white70, fontSize: 16)),
            ),
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Top-level function to show the report user bottom sheet.
void showReportUserBottomSheet(
    BuildContext context, {
      required String reportedUserId,
      required String reportedUserName,
    }) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    builder: (context) {
      return ReportUserBottomSheet(reportedUserId: reportedUserId, reportedUserName: reportedUserName);
    },
  );
}