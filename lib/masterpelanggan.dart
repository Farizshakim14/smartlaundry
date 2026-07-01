import 'package:aplikasilaundry/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/activity_service.dart';

class MasterPelangganPage extends StatefulWidget {
  final String? selectedStoreId;
  const MasterPelangganPage({super.key, this.selectedStoreId});

  @override
  State<MasterPelangganPage> createState() => _MasterPelangganPageState();
}

class _MasterPelangganPageState extends State<MasterPelangganPage> {
  String _searchQuery = '';
  String _selectedFilter = 'Semua';

  void _showCustomerDialog({String? docId, Map<String, dynamic>? customerData}) {
    if (widget.selectedStoreId == null) {
      CustomSnackbar.show(context, const SnackBar(content: Text('Pilih toko terlebih dahulu.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CustomerForm(initialData: customerData, selectedStoreId: widget.selectedStoreId!),
    ).then((resultData) async {
      if (resultData != null) {
        if (docId != null) {
          await FirebaseFirestore.instance.collection('pelanggan').doc(docId).update(resultData);
          await ActivityService.logActivity(
            storeId: widget.selectedStoreId,
            action: "Mengedit data pelanggan (${resultData['name']})",
          );
        } else {
          await FirebaseFirestore.instance.collection('pelanggan').add(resultData);
          await ActivityService.logActivity(
            storeId: widget.selectedStoreId,
            action: "Menambahkan pelanggan baru (${resultData['name']})",
          );
        }
      }
    });
  }

  void _confirmDelete(String docId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Pelanggan"),
        content: Text("Hapus $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('pelanggan').doc(docId).delete();
              await ActivityService.logActivity(
                storeId: widget.selectedStoreId,
                action: "Menghapus pelanggan ($name)",
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(String docId, Map<String, dynamic> customer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
            ListTile(
              leading: const Icon(Icons.wechat_rounded, color: Color(0xFF25D366)),
              title: const Text("Hubungi via WhatsApp", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                String phone = customer['phone']?.toString() ?? '';
                if (phone.isNotEmpty) {
                  if (phone.startsWith("0")) phone = "62${phone.substring(1)}";
                  final url = Uri.parse("https://wa.me/$phone");
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFF2563EB)),
              title: const Text("Edit Data Pelanggan", style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showCustomerDialog(docId: docId, customerData: customer);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFEF4444)),
              title: const Text("Hapus Pelanggan", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(docId, customer['name']?.toString() ?? 'Pelanggan');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
  }

  Widget _buildFilterChip(String filterValue, String label) {
    bool isSelected = _selectedFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent, // Indigo blue pill
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Pelanggan",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showCustomerDialog(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF4F46E5), // Indigo blue color
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: "Cari pelanggan...",
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildFilterChip('Semua', 'Semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pelanggan Aktif', 'Pelanggan Aktif'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pelanggan Baru', 'Pelanggan Baru'),
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            Expanded(
              child: widget.selectedStoreId == null
                ? const Center(child: Text("Silakan pilih toko di Dashboard terlebih dahulu.", style: TextStyle(color: Colors.grey)))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('transactions').where('store_id', isEqualTo: widget.selectedStoreId).snapshots(),
                    builder: (context, txSnapshot) {
                      Map<String, Map<String, int>> customerUsage = {};
                      Map<String, DateTime> lastTransaction = {};
                      
                      if (txSnapshot.hasData) {
                        for (var doc in txSnapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final cName = data['customer_name'] as String?;
                          final sType = data['service_type'] as String?;
                          final ts = data['timestamp'] as Timestamp?;
                          
                          if (cName != null) {
                            if (!customerUsage.containsKey(cName)) {
                              customerUsage[cName] = {'wash': 0, 'dry': 0};
                            }
                            if (sType == 'Wash') {
                              customerUsage[cName]!['wash'] = customerUsage[cName]!['wash']! + 1;
                            } else if (sType == 'Dry') {
                              customerUsage[cName]!['dry'] = customerUsage[cName]!['dry']! + 1;
                            } else if (sType == 'Combo') {
                              customerUsage[cName]!['wash'] = customerUsage[cName]!['wash']! + 1;
                              customerUsage[cName]!['dry'] = customerUsage[cName]!['dry']! + 1;
                            }
                            
                            if (ts != null) {
                              final dt = ts.toDate();
                              if (!lastTransaction.containsKey(cName) || dt.isAfter(lastTransaction[cName]!)) {
                                lastTransaction[cName] = dt;
                              }
                            }
                          }
                        }
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('pelanggan').where('store_id', isEqualTo: widget.selectedStoreId).snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text("Belum ada pelanggan"));
                          }

                          final allCustomers = snapshot.data!.docs;
                          
                          // Filter logic
                          List<QueryDocumentSnapshot> filteredList = [];
                          for (var doc in allCustomers) {
                            final customer = doc.data() as Map<String, dynamic>;
                            final name = customer['name']?.toString() ?? '';
                            
                            // Search Filter
                            if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery)) {
                              continue;
                            }
                            
                            int wCount = customerUsage[name]?['wash'] ?? 0;
                            int dCount = customerUsage[name]?['dry'] ?? 0;
                            int totalUsage = wCount + dCount;
                            
                            // Category Filter
                            if (_selectedFilter == 'Pelanggan Aktif' && totalUsage == 0) {
                              continue;
                            }
                            if (_selectedFilter == 'Pelanggan Baru' && totalUsage > 0) {
                              continue;
                            }
                            
                            filteredList.add(doc);
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final doc = filteredList[index];
                              final customer = doc.data() as Map<String, dynamic>;
                              final docId = doc.id;
                              final cName = customer['name']?.toString() ?? 'Tanpa Nama';
                              final phone = customer['phone']?.toString() ?? '-';
                              
                              int washCount = customerUsage[cName]?['wash'] ?? 0;
                              int dryCount = customerUsage[cName]?['dry'] ?? 0;
                              
                              String pillText;
                              Color pillColor;
                              Color pillBgColor;

                              if (washCount == 0 && dryCount == 0) {
                                pillText = "Belum Transaksi";
                                pillColor = const Color(0xFFEF4444); // Red
                                pillBgColor = const Color(0xFFEF4444).withOpacity(0.1);
                              } else if (washCount > 0 && dryCount == 0) {
                                pillText = "${washCount}x Cuci";
                                pillColor = washCount >= 5 ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
                                pillBgColor = washCount >= 5 ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFF59E0B).withOpacity(0.1);
                              } else if (washCount == 0 && dryCount > 0) {
                                pillText = "${dryCount}x Kering";
                                pillColor = const Color(0xFFF59E0B);
                                pillBgColor = const Color(0xFFF59E0B).withOpacity(0.1);
                              } else {
                                pillText = "${washCount}x Cuci + ${dryCount}x Kering";
                                pillColor = const Color(0xFFF59E0B);
                                pillBgColor = const Color(0xFFF59E0B).withOpacity(0.1);
                              }
                              
                              Color statusColor = (washCount + dryCount) > 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

                              return GestureDetector(
                                onTap: () => _showActionMenu(docId, customer),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Stack(
                                            children: [
                                              CircleAvatar(
                                                radius: 24,
                                                backgroundColor: const Color(0xFF4F46E5).withOpacity(0.1),
                                                child: Text(cName.isNotEmpty ? cName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4F46E5))),
                                              ),
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: Colors.white, width: 2),
                                                  ),
                                                ),
                                              )
                                            ],
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(cName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                                const SizedBox(height: 2),
                                                Text(phone, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Token", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(color: pillBgColor, borderRadius: BorderRadius.circular(6)),
                                                  child: Text(pillText, style: TextStyle(color: pillColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                                )
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text("Terakhir Transaksi", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                                                const SizedBox(height: 6),
                                                Text(lastTransaction[cName] != null ? _formatDate(lastTransaction[cName]!) : "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerForm extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String selectedStoreId;

  const CustomerForm({super.key, this.initialData, required this.selectedStoreId});

  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.initialData?['name'] ?? "");
    _phoneController =
        TextEditingController(text: widget.initialData?['phone'] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialData != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 DRAG INDICATOR
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            /// 🔹 TITLE
            Text(
              isEditing ? "Edit Pelanggan" : "Tambah Pelanggan",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),

            const SizedBox(height: 24),

            /// 🔹 INPUT NAMA
            TextFormField(
              controller: _nameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Nama Pelanggan",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: const Icon(Icons.person_outline),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? "Nama wajib diisi" : null,
            ),

            const SizedBox(height: 16),

            /// 🔹 INPUT HP
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Nomor WhatsApp",
                labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: const Icon(Icons.phone),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? "Nomor wajib diisi" : null,
            ),

            const SizedBox(height: 24),

            /// 🔹 BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.pop(context, {
                      "name": _nameController.text.trim(),
                      "phone": _phoneController.text.trim(),
                      "store_id": widget.selectedStoreId,
                    });
                  }
                },
                child: const Text(
                  "Simpan",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
