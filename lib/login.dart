import 'package:aplikasilaundry/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; 
import 'forgot_password.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  Future<void> signInWithGoogle() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      UserCredential userCredential;

      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        authProvider.setCustomParameters({'prompt': 'select_account'});
        userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        
        if (googleUser == null) {
          if (mounted) Navigator.pop(context); // User membatalkan login
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      }

      final userEmail = userCredential.user?.email;
      if (userEmail != null) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .get();

        if (querySnapshot.docs.isEmpty && userEmail != 'farizshakim.14@gmail.com') {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pop(context);
            CustomSnackbar.show(context, 
              const SnackBar(
                content: Text("Akses Ditolak: Akun Anda belum didaftarkan oleh Admin."),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Dapatkan token dari Laravel API
        final apiResult = await ApiService().loginWithGoogle(userEmail);
        
        if (!apiResult['success']) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pop(context);
            CustomSnackbar.show(context, 
              SnackBar(
                content: Text(apiResult['message'] ?? "Gagal mendapatkan akses token dari server."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context, 
          SnackBar(
            content: Text("Login gagal: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> signInWithEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      CustomSnackbar.show(context, 
        const SnackBar(content: Text("Email dan password tidak boleh kosong.", style: TextStyle(color: Colors.white))),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await ApiService().login(email, password);

      if (mounted) {
        Navigator.pop(context); // close loading dialog
        
        if (result['success']) {
          // Sinkronisasi dengan Firebase Auth (Login atau Buat Akun)
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
          } catch (e) {
            try {
              await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
            } catch (createError) {
              debugPrint("Gagal sinkronisasi Firebase Auth: $createError");
            }
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
            );
          }
        } else {
          CustomSnackbar.show(context, 
            SnackBar(
              content: Text(result['message'] ?? "Login gagal."),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        CustomSnackbar.show(context, 
          SnackBar(content: Text("Terjadi kesalahan: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image & Blue Blob
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.42,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Blue Blob Top Left
                  Positioned(
                    top: -120,
                    left: -80,
                    child: Container(
                      width: 320,
                      height: 350,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Main Image Hero (Right Side)
                  Positioned(
                    right: -20,
                    top: 60,
                    child: Image.asset(
                      'assets/welcome_hero.png',
                      height: MediaQuery.of(context).size.height * 0.32,
                      fit: BoxFit.contain,
                    ),
                  ),
                  
                  // Floating App Icon
                  Positioned(
                    top: MediaQuery.of(context).size.height * 0.12,
                    left: 24,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.local_laundry_service_rounded,
                          size: 32,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  
                  // App Title below icon
                  Positioned(
                    bottom: 10,
                    left: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Smart ",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              "Laundry",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2563EB),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "IoT",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Sistem Manajemen & Monitoring\nLaundry Berbasis IoT",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    "Selamat Datang Kembali! \u{1F44B}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Masuk untuk melanjutkan dan kelola laundry Anda dengan mudah dan real-time.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Label Email
                  Text(
                    "Email atau Nomor HP",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hintText: "Masukkan email atau nomor HP",
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Label Password
                  Text(
                    "Password",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: "Masukkan password",
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Lupa Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: Text(
                        "Lupa password?",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF), // Light blue background
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBFDBFE).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shield_rounded, color: Color(0xFF2563EB), size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Perhatian!",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Akun hanya dapat digunakan jika telah didaftarkan oleh Administrator. Anda tidak dapat login apabila akun belum terdaftar di sistem.",
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: const Color(0xFF334155),
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Color(0xFFBFDBFE)),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Silakan hubungi Administrator Laundry Anda untuk pendaftaran akun.",
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF334155),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Login Button
                  _buildLoginButton(context),
                  
                  const SizedBox(height: 24),
                  
                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "atau masuk dengan",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1)),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Google Button
                  _buildSocialButton(
                    Icons.g_mobiledata_rounded,
                    "Google",
                    signInWithGoogle,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Sign Up Link (Admin Contact)
                  GestureDetector(
                    onTap: () async {
                      final Uri url = Uri.parse('https://wa.me/6285882144478');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        debugPrint('Could not launch $url');
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 20, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF475569),
                            ),
                            children: const [
                              TextSpan(text: "Belum memiliki akun?\n"),
                              TextSpan(text: "Hubungi Administrator", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: signInWithEmail,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Masuk",
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
    IconData fallbackIcon,
    String label,
    VoidCallback onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/google_icon.png',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) => Icon(fallbackIcon, size: 24, color: Colors.red),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
