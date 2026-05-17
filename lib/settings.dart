import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/main.dart';
import 'package:aplikasilaundry/editprofile.dart';
import 'package:aplikasilaundry/change_password.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  User? user = FirebaseAuth.instance.currentUser;
  bool isEmailVerified = false;
  bool isPhoneVerified = false;
  String? phoneNumber;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  Future<void> _checkVerificationStatus() async {
    user = FirebaseAuth.instance.currentUser;
    await user?.reload(); // Refresh token
    user = FirebaseAuth.instance.currentUser; // Get updated user

    if (user != null) {
      isEmailVerified = user!.emailVerified;
      
      // Cek apakah ada nomor HP di Firebase Auth atau Firestore
      // Biasanya nomor HP terverifikasi masuk ke user.providerData
      bool hasPhoneProvider = user!.providerData.any((p) => p.providerId == 'phone');
      
      // Ambil nomor HP dari Firestore (karena di pendaftaran awal kita menyimpannya di sana)
      final doc = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user!.email).limit(1).get();
      if (doc.docs.isNotEmpty) {
        phoneNumber = doc.docs.first.data()['phone'];
        // Jika ada provider phone dan nomornya cocok/ada, berarti verified
        // Atau kita simpan status verified di Firestore
        isPhoneVerified = doc.docs.first.data()['phone_verified'] ?? hasPhoneProvider;
      }
      
      if (mounted) setState(() {});
    }
  }

  Future<void> _sendEmailVerification() async {
    try {
      await user?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Link verifikasi telah dikirim ke email Anda. Cek kotak masuk / spam."), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim email: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Fungsi sederhana untuk OTP SMS
  Future<void> _verifyPhoneNumber() async {
    if (phoneNumber == null || phoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Isi nomor WA/HP di Edit Profil terlebih dahulu."), backgroundColor: Colors.orange),
      );
      return;
    }

    String phoneFormat = phoneNumber!;
    if (phoneFormat.startsWith('0')) {
      phoneFormat = '+62${phoneFormat.substring(1)}';
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneFormat,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Otomatis terverifikasi (contoh di Android jika OTP terbaca otomatis)
        await user?.linkWithCredential(credential);
        await _markPhoneAsVerified();
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verifikasi gagal: ${e.message}"), backgroundColor: Colors.red),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        // Tampilkan dialog untuk memasukkan kode OTP
        _showOTPDialog(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _showOTPDialog(String verificationId) async {
    TextEditingController otpController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Masukkan Kode OTP"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Kode telah dikirim melalui SMS."),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Kode 6 digit"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              try {
                PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otpController.text.trim());
                await user?.linkWithCredential(credential);
                await _markPhoneAsVerified();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode OTP salah!"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Verifikasi"),
          )
        ],
      ),
    );
  }

  Future<void> _markPhoneAsVerified() async {
    final doc = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user!.email).limit(1).get();
    if (doc.docs.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(doc.docs.first.id).update({'phone_verified': true});
    }
    await _checkVerificationStatus();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nomor HP berhasil diverifikasi!"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Pengaturan", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Verifikasi
            _buildSectionTitle("Status Verifikasi"),
            _buildVerificationCard(
              title: "Email",
              subtitle: user?.email ?? "-",
              isVerified: isEmailVerified,
              onVerify: _sendEmailVerification,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 12),
            _buildVerificationCard(
              title: "WhatsApp / Nomor HP",
              subtitle: phoneNumber != null && phoneNumber!.isNotEmpty ? phoneNumber! : "Belum diatur",
              isVerified: isPhoneVerified,
              onVerify: _verifyPhoneNumber,
              icon: Icons.phone_android_outlined,
            ),
            
            const SizedBox(height: 32),

            // Akun
            _buildSectionTitle("Akun"),
            _buildSettingsMenu(
              icon: Icons.person_outline,
              title: "Edit Profile",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage())).then((_) => _checkVerificationStatus());
              },
            ),
            _buildSettingsMenu(
              icon: Icons.lock_outline,
              title: "Ubah Password",
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordPage()));
              },
            ),

            const SizedBox(height: 32),

            // Aplikasi
            _buildSectionTitle("Aplikasi"),
            _buildSettingsMenu(
              icon: Icons.language,
              title: "Bahasa",
              trailing: const Text("Indonesia", style: TextStyle(color: Colors.grey)),
              onTap: () {},
            ),
            _buildSettingsMenu(
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              title: "Mode Gelap (Dark Mode)",
              trailing: Switch(
                value: isDark,
                activeColor: const Color(0xFF2563EB),
                onChanged: (val) {
                  themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
                },
              ),
              onTap: () {
                themeNotifier.value = !isDark ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildVerificationCard({
    required String title,
    required String subtitle,
    required bool isVerified,
    required VoidCallback onVerify,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isVerified ? Colors.green.withOpacity(0.5) : Colors.red.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isVerified ? Colors.green : Colors.red).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isVerified ? Colors.green : Colors.red),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          if (isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Text("Verified", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: onVerify,
              child: const Text("Verifikasi"),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenu({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            if (trailing != null) trailing else Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
