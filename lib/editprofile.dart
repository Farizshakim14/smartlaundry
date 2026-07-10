import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aplikasilaundry/services/api_service.dart';
import 'package:aplikasilaundry/custom_snackbar.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  String? _docId;
  String? _originalPhone;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: FirebaseAuth.instance.currentUser?.displayName ?? "");
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final users = await ApiService().getUsers();
      final data = users.firstWhere((u) => u['email'] == email, orElse: () => {});

      if (data.isNotEmpty) {
        _docId = data['id']?.toString();
        
        setState(() {
          _nameController.text = data['name']?.toString() ?? FirebaseAuth.instance.currentUser?.displayName ?? "";
          _phoneController.text = data['phone']?.toString() ?? "";
          _originalPhone = _phoneController.text;
          _addressController.text = data['address']?.toString() ?? "";
        });
      }
    } catch (e) {
      print("Error loading profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = FirebaseAuth.instance.currentUser?.email;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();

    try {
      if (_docId != null) {
        // Update existing document
        Map<String, dynamic> updateData = {
          'name': name,
          'phone': phone,
          'address': address,
        };
        if (phone != _originalPhone) {
          updateData['phone_verified'] = false;
        }
        await ApiService().updateUser(_docId!, updateData);
      } else {
        // Jika dokumen belum ada (misal superadmin yang login tanpa dibuatkan via user management)
        final newDocResult = await ApiService().addUser({
          'email': email,
          'role': email == 'farizshakim.14@gmail.com' ? 'Superadmin' : 'Owner',
          'password': 'password123', // required by API
          'name': name,
          'phone': phone,
          'address': address,
          'phone_verified': false,
        });
        if (newDocResult['success']) {
          _docId = newDocResult['user']['id']?.toString();
        }
      }
      
      // Update Firebase Auth profile
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);

      if (mounted) {
        CustomSnackbar.show(context, 
          const SnackBar(
            content: Text('Profil berhasil diperbarui!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 
          SnackBar(content: Text('Gagal memperbarui profil: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? const Color(0xFF1E293B),
        elevation: 0,
        title: const Text("Edit Profile", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                        ),
                        child: const Icon(Icons.person, size: 50, color: Color(0xFF2563EB)),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: _inputDecoration("Enter your name"),
                      validator: (v) => v!.isEmpty ? "Name cannot be empty" : null,
                    ),
                    const SizedBox(height: 16),

                    Text("Phone Number", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: _inputDecoration("e.g. 08123456789"),
                    ),
                    const SizedBox(height: 16),

                    Text("Address", style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 3,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      decoration: _inputDecoration("Enter your full address"),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[500]),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

