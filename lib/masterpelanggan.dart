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

  void _showCustomerDialog({String? docId, Map<String, dynamic>? customerData}) {
    if (widget.selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih toko terlebih dahulu.')));
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
            onPressed: () async {
              await FirebaseFirestore.instance.collection('pelanggan').doc(docId).delete();
              await ActivityService.logActivity(
                storeId: widget.selectedStoreId,
                action: "Menghapus pelanggan ($name)",
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Master Pelanggan",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.selectedStoreId == null
              ? const Center(child: Text("Silakan pilih toko di Dashboard terlebih dahulu.", style: TextStyle(color: Colors.grey)))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('transactions').where('store_id', isEqualTo: widget.selectedStoreId).snapshots(),
                  builder: (context, txSnapshot) {
                    Map<String, Map<String, int>> customerUsage = {};
                    if (txSnapshot.hasData) {
                      for (var doc in txSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final cName = data['customer_name'] as String?;
                        final sType = data['service_type'] as String?;
                        
                        if (cName != null && sType != null) {
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

          final customers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final doc = customers[index];
              final customer = doc.data() as Map<String, dynamic>;
              final docId = doc.id;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                      child: Text(customer['name']?.toString().isNotEmpty == true ? customer['name'].toString()[0].toUpperCase() : '?'),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer['name']?.toString() ?? 'Tanpa Nama', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                          Text(customer['phone']?.toString() ?? '-', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text("Washer: ${customerUsage[customer['name']]?['wash'] ?? 0}x", style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text("Dryer: ${customerUsage[customer['name']]?['dry'] ?? 0}x", style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.wechat_rounded, color: Color(0xFF25D366)),
                          onPressed: () async {
                            String phone = customer['phone']?.toString() ?? '';
                            if (phone.isNotEmpty) {
                              if (phone.startsWith("0")) {
                                phone = "62${phone.substring(1)}";
                              }

                              final url = Uri.parse("https://wa.me/$phone");
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            }
                          },
                        ),

                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showCustomerDialog(docId: docId, customerData: customer);
                            } else {
                              _confirmDelete(docId, customer['name']?.toString() ?? 'Pelanggan');
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text("Edit")),
                            PopupMenuItem(value: 'delete', child: Text("Hapus")),
                          ],
                        ),
                      ],
                    ),
                  ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        label: const Text("Tambah Pelanggan"),
        icon: const Icon(Icons.person_add),
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