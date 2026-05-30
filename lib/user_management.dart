import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserManagementPage extends StatefulWidget {
  final String currentRole;

  const UserManagementPage({super.key, required this.currentRole});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {

  List<Map<String, dynamic>> _myStores = [];
  bool _isLoadingStores = true;

  @override
  void initState() {
    super.initState();
    _fetchMyStores();
  }

  Future<void> _fetchMyStores() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      Query q = FirebaseFirestore.instance.collection('stores');
      if (widget.currentRole == 'Owner') {
        q = q.where('owner_email', isEqualTo: user.email);
      }
      final snap = await q.get();
      _myStores = snap.docs.map((d) => {
        'id': d.id,
        'name': (d.data() as Map<String, dynamic>)['name']?.toString() ?? 'Unnamed Store'
      }).toList();
    }
    setState(() {
      _isLoadingStores = false;
    });
  }

  List<String> _getAllowedRoles() {
    switch (widget.currentRole) {
      case "Superadmin":
        return ["Admin", "Owner"];
      case "Admin":
        return ["Owner"];
      case "Owner":
        return ["Cashier"];
      default:
        return [];
    }
  }

  void _showAddUserDialog() {
    final allowedRoles = _getAllowedRoles();
    
    if (allowedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak memiliki izin untuk membuat pengguna baru.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddUserForm(
        allowedRoles: allowedRoles, 
        currentRole: widget.currentRole,
        myStores: _myStores,
      ),
    ).then((newUser) async {
      if (newUser != null) {
        await FirebaseFirestore.instance.collection('users').add(newUser);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newUser["name"]} berhasil ditambahkan sebagai ${newUser["role"]}!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _confirmDeleteUser(String docId, String name, String email, String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Pengguna"),
        content: Text("Apakah Anda yakin ingin menghapus akun $name?\nTindakan ini tidak dapat dibatalkan" + 
          (role == 'Owner' ? "\n\n⚠️ PERINGATAN: Menghapus Owner akan ikut menghapus SEMUA TOKO, mesin, kasir, pelanggan, dan riwayat transaksinya!" : ".")),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); // Tutup dialog confirmation
              
              // Tampilkan loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // 1. Hapus akun dari Firebase Auth lewat API Backend (VPS)
                try {
                  final response = await http.post(
                    Uri.parse('http://103.150.226.111:3000/delete-user'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'email': email}),
                  );
                  print("Auth deletion response: ${response.body}");
                } catch (e) {
                  print("Warning: Gagal menghapus Auth: $e");
                }

                // 2. Cascade Delete jika Owner
                if (role == 'Owner' && email.isNotEmpty) {
                  final storesSnap = await FirebaseFirestore.instance.collection('stores').where('owner_email', isEqualTo: email).get();
                  
                  for (var storeDoc in storesSnap.docs) {
                    final storeId = storeDoc.id;
                    final batch = FirebaseFirestore.instance.batch();
                    
                    // Hapus mesin
                    final machines = await FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: storeId).get();
                    for (var doc in machines.docs) { batch.delete(doc.reference); }
                    
                    // Hapus pelanggan
                    final pelanggan = await FirebaseFirestore.instance.collection('pelanggan').where('store_id', isEqualTo: storeId).get();
                    for (var doc in pelanggan.docs) { batch.delete(doc.reference); }
                    
                    // Hapus cashier (selain owner ini)
                    final cashiers = await FirebaseFirestore.instance.collection('users').where('store_id', isEqualTo: storeId).get();
                    for (var doc in cashiers.docs) { batch.delete(doc.reference); }
                    
                    // Hapus tokonya
                    batch.delete(storeDoc.reference);
                    
                    await batch.commit();
                  }
                }

                // 3. Terakhir hapus profil user-nya dari koleksi 'users'
                await FirebaseFirestore.instance.collection('users').doc(docId).delete();
                
                if (mounted) {
                  Navigator.pop(context); // Tutup loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Akun $name berhasil dihapus secara bersih'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Tutup loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Hapus Permanen", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canAddUser = _getAllowedRoles().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "User Management",
          style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: _isLoadingStores
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada pengguna",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          final users = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            if (widget.currentRole == 'Superadmin' || widget.currentRole == 'Admin') return true;
            
            // For Owner, show themselves or their cashiers
            if (data['email'] == FirebaseAuth.instance.currentUser?.email) return true;
            if (data['role'] == 'Cashier' && _myStores.any((s) => s['id'] == data['store_id'])) return true;
            
            return false;
          }).toList();

          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada pengguna",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final user = doc.data() as Map<String, dynamic>;
              
              final name = user['name']?.toString() ?? 'Unknown User';
              final email = user['email']?.toString() ?? 'No Email';
              final role = user['role']?.toString() ?? 'Cashier';
              
              Color roleColor;
              switch (role) {
                case 'Admin':
                  roleColor = const Color(0xFF2563EB); // Royal Blue
                  break;
                case 'Owner':
                  roleColor = const Color(0xFFF59E0B); // Amber
                  break;
                default:
                  roleColor = const Color(0xFF10B981); // Emerald (Cashier)
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
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
                      backgroundColor: roleColor.withOpacity(0.1),
                      radius: 24,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (widget.currentRole == 'Superadmin') ...[
                            if (user['phone'] != null && user['phone'].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(
                                    user['phone'].toString(),
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                            if (user['address'] != null && user['address'].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user['address'].toString(),
                                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (canAddUser)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteUser(doc.id, name, email, role),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: canAddUser
          ? FloatingActionButton.extended(
              onPressed: _showAddUserDialog,
              backgroundColor: const Color(0xFF2563EB),
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: const Text("Add User", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null, // Sembunyikan FAB jika tidak punya izin
    );
  }
}

class AddUserForm extends StatefulWidget {
  final List<String> allowedRoles;
  final String currentRole;
  final List<Map<String, dynamic>> myStores;

  const AddUserForm({
    super.key, 
    required this.allowedRoles, 
    required this.currentRole, 
    required this.myStores,
  });

  @override
  State<AddUserForm> createState() => _AddUserFormState();
}

class _AddUserFormState extends State<AddUserForm> {
  final _formKey = GlobalKey<FormState>();
  String _name = "";
  String _email = "";
  String? _selectedRole;
  String? _selectedStoreId;

  @override
  void initState() {
    super.initState();
    if (widget.allowedRoles.isNotEmpty) {
      _selectedRole = widget.allowedRoles.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Create New User",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Input Nama
              const Text(
                "Full Name",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: InputDecoration(
                  hintText: "Enter full name",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? "Name cannot be empty" : null,
                onSaved: (value) => _name = value!.trim(),
              ),
              const SizedBox(height: 16),

              // Input Email
              const Text(
                "Email Address",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: "Enter email address",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) => value == null || !value.contains('@') ? "Enter a valid email" : null,
                onSaved: (value) => _email = value!.trim(),
              ),
              const SizedBox(height: 16),

              // Dropdown Role
              const Text(
                "Assign Role",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: widget.allowedRoles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                  });
                },
                validator: (value) => value == null ? "Please select a role" : null,
              ),
              if (_selectedRole == 'Cashier' && widget.myStores.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("Tugaskan ke Toko", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedStoreId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  items: widget.myStores.map((store) {
                    return DropdownMenuItem(
                      value: store['id'].toString(),
                      child: Text(store['name'].toString()),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedStoreId = value),
                  validator: (value) => _selectedRole == 'Cashier' && value == null ? "Silakan pilih toko" : null,
                ),
              ],
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      Navigator.pop(context, {
                        "name": _name,
                        "email": _email,
                        "role": _selectedRole!,
                        if (_selectedRole == 'Cashier' && _selectedStoreId != null) "store_id": _selectedStoreId,
                      });
                    }
                  },
                  child: const Text(
                    "Create User",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
