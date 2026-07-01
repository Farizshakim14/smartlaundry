import 'package:aplikasilaundry/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKeyAccount = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKeyPin = GlobalKey<FormState>();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _obscureOldPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;
  
  String? _userStoreId;

  @override
  void initState() {
    super.initState();
    _fetchUserStoreId();
  }

  Future<void> _fetchUserStoreId() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      final doc = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();
      if (doc.docs.isNotEmpty) {
        setState(() {
          _userStoreId = doc.docs.first.data()['store_id'];
        });
      }
    }
  }

  Future<void> _changeAccountPassword() async {
    if (!_formKeyAccount.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _oldPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);

        if (mounted) {
          CustomSnackbar.show(context, 
            const SnackBar(content: Text("Password berhasil diubah!"), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Gagal mengubah password";
      if (e.code == 'wrong-password') {
        msg = "Password lama salah!";
      } else if (e.code == 'weak-password') {
        msg = "Password baru terlalu lemah.";
      }
      if (mounted) CustomSnackbar.show(context, SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) CustomSnackbar.show(context, SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeCustomerModePin() async {
    if (!_formKeyPin.currentState!.validate()) return;
    
    if (_userStoreId == null || _userStoreId!.isEmpty) {
      CustomSnackbar.show(context, const SnackBar(content: Text("Anda belum memiliki cabang toko."), backgroundColor: Colors.orange));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final storeRef = FirebaseFirestore.instance.collection('stores').doc(_userStoreId);
      final storeSnap = await storeRef.get();
      if (storeSnap.exists) {
        String currentPin = storeSnap.data()?['customer_mode_pin'] ?? '1234';
        
        if (_oldPinController.text != currentPin) {
          if (mounted) CustomSnackbar.show(context, const SnackBar(content: Text("PIN lama salah!"), backgroundColor: Colors.red));
          setState(() { _isLoading = false; });
          return;
        }

        await storeRef.update({
          'customer_mode_pin': _newPinController.text,
        });

        if (mounted) {
          CustomSnackbar.show(context, const SnackBar(content: Text("PIN Mode Pelanggan berhasil diubah!"), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) CustomSnackbar.show(context, SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Ubah Keamanan", style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
          foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? const Color(0xFF1E293B),
          bottom: const TabBar(
            labelColor: Color(0xFF2563EB),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF2563EB),
            tabs: [
              Tab(text: "Password Akun"),
              Tab(text: "PIN Mode Pelanggan"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Akun Password
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKeyAccount,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Keamanan Akun", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Text("Harap masukkan password lama Anda untuk memverifikasi identitas.", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 32),
                    _buildPasswordField(
                      controller: _oldPasswordController,
                      label: "Password Lama",
                      obscureText: _obscureOld,
                      onToggle: () => setState(() => _obscureOld = !_obscureOld),
                      validator: (val) => val == null || val.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _newPasswordController,
                      label: "Password Baru",
                      obscureText: _obscureNew,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Wajib diisi";
                        if (val.length < 6) return "Minimal 6 karakter";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: "Konfirmasi Password Baru",
                      obscureText: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Wajib diisi";
                        if (val != _newPasswordController.text) return "Password tidak cocok";
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: _isLoading ? null : _changeAccountPassword,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Ubah Password Akun", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Tab 2: Customer Mode PIN
            SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKeyPin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("PIN Mode Pelanggan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1E293B))),
                    const SizedBox(height: 8),
                    Text("Ubah PIN khusus admin yang digunakan untuk keluar dari layar Mode Pelanggan (Kiosk). PIN default adalah 1234.", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                    const SizedBox(height: 32),
                    _buildPasswordField(
                      controller: _oldPinController,
                      label: "PIN Lama",
                      obscureText: _obscureOldPin,
                      keyboardType: TextInputType.number,
                      onToggle: () => setState(() => _obscureOldPin = !_obscureOldPin),
                      validator: (val) => val == null || val.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _newPinController,
                      label: "PIN Baru",
                      obscureText: _obscureNewPin,
                      keyboardType: TextInputType.number,
                      onToggle: () => setState(() => _obscureNewPin = !_obscureNewPin),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Wajib diisi";
                        if (val.length < 4) return "Minimal 4 angka";
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPinController,
                      label: "Konfirmasi PIN Baru",
                      obscureText: _obscureConfirmPin,
                      keyboardType: TextInputType.number,
                      onToggle: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                      validator: (val) {
                        if (val == null || val.isEmpty) return "Wajib diisi";
                        if (val != _newPinController.text) return "PIN tidak cocok";
                        return null;
                      },
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: _isLoading ? null : _changeCustomerModePin,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Ubah PIN Pelanggan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
