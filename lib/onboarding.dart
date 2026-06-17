import 'package:flutter/material.dart';
import 'package:aplikasilaundry/welcome_page.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _onboardingData = [
    {
      "title1": "Kontrol Mesin\n",
      "title2": "dari Mana Saja",
      "desc": "Nyalakan atau matikan mesin cuci langsung dari aplikasi. Terhubung dengan IoT untuk kontrol real-time.",
      "image": "assets/onboarding_1.png",
    },
    {
      "title1": "Pantau Operasional\n",
      "title2": "Secara Real-time",
      "desc": "Lihat status mesin, transaksi, pendapatan, dan aktivitas laundry dalam satu dashboard yang lengkap.",
      "image": "assets/onboarding_2.png",
    },
    {
      "title1": "Pembayaran Mudah\n",
      "title2": "& Aman",
      "desc": "Terima pembayaran digital dengan QRIS & Midtrans. Transaksi lebih cepat, aman, dan tercatat otomatis.",
      "image": "assets/onboarding_3.png",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header (Lewati Button)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomePage()),
                      );
                    },
                    child: const Text(
                      "Lewati",
                      style: TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  return AnimatedBuilder(
                    animation: Listenable.merge([_pageController, _floatController]),
                    builder: (context, child) {
                      double value = 1.0;
                      double pageOffset = 0.0;
                      if (_pageController.position.haveDimensions) {
                        pageOffset = _pageController.page! - index;
                        value = (1 - (pageOffset.abs() * 0.3)).clamp(0.0, 1.0);
                      }
                      
                      // Parallax effect for image
                      double translation = pageOffset * 200;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated Image Area
                            Expanded(
                              flex: 5,
                              child: Transform.translate(
                                offset: Offset(translation, _floatController.value * -15), // Floating effect
                                child: Opacity(
                                  opacity: value,
                                  child: Transform.scale(
                                    scale: value,
                                    child: Center(
                                      child: Container(
                                        width: MediaQuery.of(context).size.width * 0.7,
                                        height: MediaQuery.of(context).size.width * 0.7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2563EB).withOpacity(0.1),
                                              blurRadius: 40,
                                              spreadRadius: 10,
                                            )
                                          ],
                                          image: DecorationImage(
                                            image: AssetImage(_onboardingData[index]["image"]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Text Section
                            Expanded(
                              flex: 4,
                              child: Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 50 * pageOffset.abs()),
                                  child: Column(
                                    children: [
                                      // Title with curved animation and GoogleFonts
                                      Transform.translate(
                                        offset: Offset(0, 20 * Curves.easeOutQuad.transform(pageOffset.abs().clamp(0.0, 1.0))),
                                        child: RichText(
                                          textAlign: TextAlign.center,
                                          text: TextSpan(
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                              letterSpacing: -0.5,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: _onboardingData[index]["title1"],
                                                style: const TextStyle(color: Color(0xFF0F172A)),
                                              ),
                                              TextSpan(
                                                text: _onboardingData[index]["title2"],
                                                style: TextStyle(
                                                  color: index == 2 ? const Color(0xFF0F172A) : const Color(0xFF2563EB)
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      // Description with a slight delay/different curve
                                      Transform.translate(
                                        offset: Offset(0, 40 * Curves.easeOutCubic.transform(pageOffset.abs().clamp(0.0, 1.0))),
                                        child: Opacity(
                                          opacity: Curves.easeIn.transform(value),
                                          child: Text(
                                            _onboardingData[index]["desc"],
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              fontSize: 15,
                                              color: const Color(0xFF64748B),
                                              height: 1.6,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Footer (Dots and Button)
            Padding(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _onboardingData.length,
                      (index) => buildDot(index, context),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _onboardingData.length - 1) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const WelcomePage()),
                          );
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == _onboardingData.length - 1 ? "Mulai Sekarang" : "Berikutnya",
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDot(int index, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
