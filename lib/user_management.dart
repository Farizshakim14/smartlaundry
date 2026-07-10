import 'package:aplikasilaundry/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aplikasilaundry/services/api_service.dart';

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
    try {
      final stores = await ApiService().getStores();
      if (mounted) {
        setState(() {
          _myStores = stores.map((d) => {
            'id': d['id'].toString(),
            'name': d['name']?.toString() ?? 'Unnamed Store'
          }).toList();
          _isLoadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStores = false;
        });
      }
    }
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
      CustomSnackbar.show(context, 
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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );

        final apiResult = await ApiService().addUser({
          "name": newUser["name"],
          "email": newUser["email"],
          "password": newUser["password"],
          "role": newUser["role"],
          "store_id": newUser["store_id"],
        });

        if (mounted) {
          Navigator.pop(context); // Tutup loading
        }

        if (apiResult['success']) {
          if (mounted) {
            setState(() {}); // Refresh list
            CustomSnackbar.show(context, 
              SnackBar(
                content: Text('${newUser["name"]} berhasil ditambahkan sebagai ${newUser["role"]}!'),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (mounted) {
            CustomSnackbar.show(context, 
              SnackBar(
                content: Text(apiResult['message'] ?? 'Gagal membuat pengguna di server.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    });
  }

  void _confirmDeleteUser(String docId, String name, String email, String role) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Hapus Pengguna"),
        content: Text("Apakah Anda yakin ingin menghapus akun $name?\nTindakan ini tidak dapat dibatalkan" + 
          (role == 'Owner' ? "\n\n⚠️ PERINGATAN: Menghapus Owner akan ikut menghapus SEMUA TOKO, mesin, kasir, pelanggan, dan riwayat transaksinya!" : ".")),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); // Tutup dialog confirmation
              
              // Tampilkan loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // Hapus akun dari API Backend Laravel
                final success = await ApiService().deleteUserById(docId);
                
                if (mounted) {
                  Navigator.pop(context); // Tutup loading dialog
                }
                
                if (success) {
                  if (mounted) {
                    setState(() {}); // Refresh list
                    CustomSnackbar.show(context, 
                      SnackBar(content: Text('Akun $name berhasil dihapus'), backgroundColor: Colors.green),
                    );
                  }
                } else {
                  if (mounted) {
                    CustomSnackbar.show(context, SnackBar(content: Text('Gagal menghapus di server'), backgroundColor: Colors.red));
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Tutup loading dialog
                  CustomSnackbar.show(context, 
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
        : FutureBuilder<List<Map<String, dynamic>>>(
        future: ApiService().getUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

          final users = snapshot.data!.where((data) {
            if (widget.currentRole == 'Superadmin' || widget.currentRole == 'Admin') return true;
            
            // For Owner, show themselves or their cashiers
            if (data['email'] == FirebaseAuth.instance.currentUser?.email) return true;
            if (data['role'] == 'Cashier' && _myStores.any((s) => s['id'] == data['store_id']?.toString())) return true;
            
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
              final user = users[index];
              final docId = user['id']?.toString() ?? '';
              
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
                        onPressed: () => _confirmDeleteUser(docId, name, email, role),
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
  String _password = "";
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

              // Input Password
              const Text(
                "Password",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                obscureText: true,
                decoration: InputDecoration(
                  hintText: "Enter password (min 8 chars)",
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) => value == null || value.length < 8 ? "Password minimum 8 characters" : null,
                onSaved: (value) => _password = value!,
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
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                borderRadius: BorderRadius.circular(16),
                style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
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
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                  borderRadius: BorderRadius.circular(16),
                  style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
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
                        "password": _password,
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

