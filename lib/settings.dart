import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/main.dart';
import 'package:aplikasilaundry/editprofile.dart';
import 'package:aplikasilaundry/change_password.dart';
import 'package:aplikasilaundry/localization.dart';

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

  StreamSubscription<QuerySnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _checkVerificationStatus() {
    user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    user?.reload().then((_) {
      if (mounted) {
        setState(() {
          user = FirebaseAuth.instance.currentUser;
          isEmailVerified = user?.emailVerified ?? false;
        });
      }
    });

    bool hasPhoneProvider = user!.providerData.any((p) => p.providerId == 'phone');

    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: user!.email)
        .limit(1)
        .snapshots()
        .listen((doc) {
      if (doc.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            phoneNumber = doc.docs.first.data()['phone'];
            isPhoneVerified = doc.docs.first.data()['phone_verified'] ?? hasPhoneProvider;
          });
        }
      }
    });
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
    // Listener will automatically update the UI
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
        title: Text(AppLocalizations.tr('settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
            _buildSectionTitle(AppLocalizations.tr('verification_status')),
            _buildVerificationCard(
              title: AppLocalizations.tr('email'),
              subtitle: user?.email ?? "-",
              isVerified: isEmailVerified,
              onVerify: _sendEmailVerification,
              icon: Icons.email_outlined,
            ),
            const SizedBox(height: 12),
            _buildVerificationCard(
              title: AppLocalizations.tr('phone_number'),
              subtitle: phoneNumber != null && phoneNumber!.isNotEmpty ? phoneNumber! : AppLocalizations.tr('not_set'),
              isVerified: isPhoneVerified,
              onVerify: _verifyPhoneNumber,
              icon: Icons.phone_android_outlined,
            ),
            
            const SizedBox(height: 32),

            // Akun
            _buildSectionTitle(AppLocalizations.tr('account')),
            _buildSettingsMenu(
              icon: Icons.person_outline,
              title: AppLocalizations.tr('edit_profile'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
              },
            ),
            _buildSettingsMenu(
              icon: Icons.lock_outline,
              title: AppLocalizations.tr('change_password'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordPage()));
              },
            ),

            const SizedBox(height: 32),

            // Aplikasi
            _buildSectionTitle(AppLocalizations.tr('application')),
            _buildSettingsMenu(
              icon: Icons.language,
              title: AppLocalizations.tr('language'),
              trailing: Text(AppLocalizations.currentLanguage.value == 'id' ? AppLocalizations.tr('indonesian') : AppLocalizations.tr('english'), style: const TextStyle(color: Colors.grey)),
              onTap: () {
                _showLanguageDialog();
              },
            ),
            _buildSettingsMenu(
              icon: isDark ? Icons.dark_mode : Icons.light_mode,
              title: AppLocalizations.tr('dark_mode'),
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
              child: Text(AppLocalizations.tr('verified'), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
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
              child: Text(AppLocalizations.tr('verify')),
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
  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.tr('language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.tr('indonesian')),
              trailing: AppLocalizations.currentLanguage.value == 'id' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                AppLocalizations.changeLanguage('id');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(AppLocalizations.tr('english')),
              trailing: AppLocalizations.currentLanguage.value == 'en' ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                AppLocalizations.changeLanguage('en');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
