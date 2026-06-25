import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ActivityLogPage extends StatefulWidget {
  final String? initialStoreId;
  final List<Map<String, dynamic>> stores;
  final String userRole;

  const ActivityLogPage({
    super.key,
    this.initialStoreId,
    required this.stores,
    required this.userRole,
  });

  @override
  State<ActivityLogPage> createState() => _ActivityLogPageState();
}

class _ActivityLogPageState extends State<ActivityLogPage> {
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    _selectedStoreId = widget.initialStoreId ?? 'ALL';
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Belum ada riwayat aktivitas", style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ambil data hanya berdasarkan waktu untuk menghindari error Composite Index Firebase
    Query query = FirebaseFirestore.instance.collection('activities').orderBy('timestamp', descending: true).limit(200);
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        elevation: 0,
        title: Text("Notifikasi & Riwayat", style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor ?? const Color(0xFF1E293B), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.foregroundColor ?? const Color(0xFF1E293B)),
        bottom: widget.userRole != 'Cashier' && widget.stores.isNotEmpty ? PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoreId,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14),
                  isDense: true,
                  items: [
                    if (!widget.stores.any((s) => s['id'] == 'ALL'))
                      const DropdownMenuItem<String>(value: 'ALL', child: Text("Semua Toko")),
                    ...widget.stores.map((s) => DropdownMenuItem<String>(value: s['id'] as String, child: Text(s['name'] as String)))
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedStoreId = val;
                    });
                  },
                ),
              ),
            ),
          ),
        ) : null,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          // FILTER LOKAL DI DART (Mencegah Composite Index Error di Firebase)
          var docs = snapshot.data!.docs;
          if (widget.userRole == 'Cashier') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['store_id'] == (widget.initialStoreId ?? 'NO_STORE');
            }).toList();
          } else if (_selectedStoreId != null && _selectedStoreId != 'ALL') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return data['store_id'] == _selectedStoreId;
            }).toList();
          } else if (widget.userRole == 'Owner') {
            List<String> myStoreIds = widget.stores.map((s) => s['id'] as String).toList();
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              return myStoreIds.contains(data['store_id']);
            }).toList();
          }

          if (docs.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              final userName = data['user_name'] ?? 'Sistem';
              final action = data['action'] ?? 'Melakukan sesuatu';
              final role = data['user_role'] ?? 'Unknown';
              final Timestamp? ts = data['timestamp'];
              
              String timeStr = "";
              if (ts != null) {
                timeStr = DateFormat('dd MMM yyyy, HH:mm').format(ts.toDate());
              }

              IconData icon = Icons.info_outline;
              Color iconColor = const Color(0xFF3B82F6);
              
              if (action.toString().toLowerCase().contains('hapus') || action.toString().toLowerCase().contains('delete')) {
                icon = Icons.delete_outline;
                iconColor = const Color(0xFFEF4444);
              } else if (action.toString().toLowerCase().contains('tambah') || action.toString().toLowerCase().contains('add')) {
                icon = Icons.add_circle_outline;
                iconColor = const Color(0xFF10B981);
              } else if (action.toString().toLowerCase().contains('edit') || action.toString().toLowerCase().contains('update')) {
                icon = Icons.edit_outlined;
                iconColor = const Color(0xFFF59E0B);
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                              children: [
                                TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                TextSpan(text: " ($role) ", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontSize: 12)),
                                TextSpan(text: action),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(timeStr, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        ],
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
