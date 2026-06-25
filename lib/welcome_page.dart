import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';
import 'package:url_launcher/url_launcher.dart';
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _floatController;
  late Animation<double> _imageAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _gridAnimation;
  late Animation<double> _infoBoxAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _imageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _gridAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _infoBoxAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _mainController.forward();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. Hero Image with Animation
            AnimatedBuilder(
              animation: Listenable.merge([_imageAnimation, _floatController]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, (50 * (1 - _imageAnimation.value)) + (_floatController.value * -10)),
                  child: Opacity(
                    opacity: _imageAnimation.value.clamp(0.0, 1.0),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                          child: Center(
                            child: Image.asset(
                              'assets/welcome_hero.png',
                              fit: BoxFit.contain,
                              height: MediaQuery.of(context).size.height * 0.35,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  
                  // 2. Title & Subtitle
                  AnimatedBuilder(
                    animation: _titleAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _titleAnimation.value)),
                        child: Opacity(
                          opacity: _titleAnimation.value.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    "Smart ",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    "Laundry",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2563EB),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "IoT",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Sistem Manajemen & Monitoring Laundry\nBerbasis IoT",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // 3. Feature Grid
                  AnimatedBuilder(
                    animation: _gridAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.95 + (0.05 * _gridAnimation.value),
                        child: Opacity(
                          opacity: _gridAnimation.value.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildFeatureCard(Icons.phonelink_setup, "Kontrol Mesin IoT", "Nyalakan/matikan jarak jauh.", const Color(0xFF2563EB))),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildFeatureCard(Icons.analytics_rounded, "Monitoring Real-time", "Pantau status kapan saja.", const Color(0xFF10B981))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildFeatureCard(Icons.account_balance_wallet_rounded, "Pembayaran Digital", "Terima pembayaran QRIS & Midtrans.", const Color(0xFF8B5CF6))),
                                  const SizedBox(width: 16),
                                  Expanded(child: const SizedBox()), // Empty space for layout balance or a 4th feature
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // 4. Info Box (Akses Khusus)
                  AnimatedBuilder(
                    animation: _infoBoxAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - _infoBoxAnimation.value)),
                        child: Opacity(
                          opacity: _infoBoxAnimation.value.clamp(0.0, 1.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF), // Light blue background
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Akses Khusus Pengguna Terdaftar",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Untuk menjaga keamanan data dan operasional laundry, hanya akun yang telah didaftarkan oleh Administrator yang dapat masuk ke sistem.",
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF475569),
                                    height: 1.5,
                                  ),
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
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: const Color(0xFF475569),
                                            height: 1.5,
                                          ),
                                          children: const [
                                            TextSpan(text: "Anda "),
                                            TextSpan(text: "tidak dapat login", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                            TextSpan(text: " apabila akun belum terdaftar. Silakan hubungi Administrator Laundry Anda."),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // 5. Action Buttons
                  AnimatedBuilder(
                    animation: _buttonAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - _buttonAnimation.value)),
                        child: Opacity(
                          opacity: _buttonAnimation.value.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const LoginPage()),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Masuk ke Akun",
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
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final Uri url = Uri.parse('https://wa.me/6285882144478');
                                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                                      debugPrint('Could not launch $url');
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF2563EB),
                                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.support_agent_rounded, size: 18),
                                        const SizedBox(width: 8),
                                        RichText(
                                          text: TextSpan(
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: const Color(0xFF475569),
                                            ),
                                            children: const [
                                              TextSpan(text: "Belum memiliki akun? "),
                                              TextSpan(text: "Hubungi Administrator", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
