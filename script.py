import re

file_path = r'f:\Projects\flowLive\FlowLive\lib\ui\apply\apply_hosting.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    'final Map<String, String> _pendingRequestDocIds = {};',
    'final Map<String, String> _pendingRequestDocIds = {};\n  final Map<String, dynamic> _pendingRequestDetails = {};'
)

fetch_target = '''            pendingIds.add(agId.toString());
            requestDocs[agId.toString()] = doc.id;
          }'''
fetch_replacement = '''            pendingIds.add(agId.toString());
            requestDocs[agId.toString()] = doc.id;
            _pendingRequestDetails[agId.toString()] = data;
          }'''
content = content.replace(fetch_target, fetch_replacement)

send_target = '''      setState(() {
        _pendingAgencyIds.add(agency['agentUserId'].toString());
        _pendingRequestDocIds[agency['agentUserId'].toString()] = docRef.id;
      });'''
send_replacement = '''      setState(() {
        _pendingAgencyIds.add(agency['agentUserId'].toString());
        _pendingRequestDocIds[agency['agentUserId'].toString()] = docRef.id;
        _pendingRequestDetails[agency['agentUserId'].toString()] = {
          'liveType': liveType,
          'createdAt': DateTime.now().toString(),
        };
      });'''
content = content.replace(send_target, send_replacement)

build_target = '''  @override
  Widget build(BuildContext context) {'''
build_replacement = '''  String _formatDate(dynamic dt) {
    if (dt == null) return '';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is String) {
      return dt;
    } else {
      date = DateTime.now();
    }
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayStr = days[date.weekday - 1];
    final hr = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final min = date.minute.toString().padLeft(2, '0');
    final sec = date.second.toString().padLeft(2, '0');
    return '$dayStr, ${date.month}/${date.day}/${date.year} $hr:$min:$sec $ampm';
  }

  Widget _buildPendingUI() {
    final pendingId = _pendingAgencyIds.first;
    final details = _pendingRequestDetails[pendingId] ?? {};
    final liveType = details['liveType'] ?? 'Video Live';
    final dateStr = _formatDate(details['createdAt']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF1E2124)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Your host request ($liveType) is\\npending. Please wait.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 140,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _cancelHostRequest(pendingId),
              icon: const Icon(Icons.power_settings_new, color: Colors.white, size: 20),
              label: const Text('Remove', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {'''
content = content.replace(build_target, build_replacement)

build_content_target = '''            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    // Search Bar'''
build_content_replacement = '''            // Content
            Expanded(
              child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFE62563)))
                  : _pendingAgencyIds.isNotEmpty 
                      ? _buildPendingUI() 
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            children: [
                              // Search Bar'''
content = content.replace(build_content_target, build_content_replacement)

old_loading_target = '''                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE62563)))
                          : filteredAgencies.isEmpty
                              ? const Center('''
old_loading_replacement = '''                    Expanded(
                      child: filteredAgencies.isEmpty
                              ? const Center('''
content = content.replace(old_loading_target, old_loading_replacement)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Update complete")
