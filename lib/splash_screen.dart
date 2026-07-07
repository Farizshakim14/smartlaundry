import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'onboarding.dart';
import 'dashboard.dart';
import 'services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _mainController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeIn),
    );
    
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutCubic),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _mainController.forward();

    Timer(const Duration(milliseconds: 3500), () async {
      final token = await ApiService().getToken();
      Widget next = token != null ? const DashboardPage() : const OnboardingPage();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (_, __, ___) => next,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Animated Background Wave
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: WavePainter(
                  color: const Color(0xFF2563EB),
                  offset: _waveController.value * 20,
                ),
              );
            }
          ),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // 3D Illustration
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    
                    // Logo Title
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Smart ",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          "Laundry ",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2563EB),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF2563EB), width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "IoT",
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Sistem Manajemen & Monitoring Laundry",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Feature Cards
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureCard("Kontrol Mesin\nIoT", Icons.memory, const Color(0xFF2563EB)),
                          _buildFeatureCard("Monitoring\nReal-time", Icons.bar_chart, const Color(0xFF10B981)),
                          _buildFeatureCard("Pembayaran\nDigital", Icons.qr_code, const Color(0xFF8B5CF6)),
                          _buildFeatureCard("Kelola\nPelanggan", Icons.people, const Color(0xFFF59E0B)),
                        ],
                      ),
                    ),
                    
                    Expanded(flex: 3, child: Container()), // Push bottom elements down
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom Loading
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const AnimatedDots(),
                  const SizedBox(height: 16),
                  Text(
                    "Memuat data, mohon tunggu...",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  final double offset;

  WavePainter({required this.color, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    // Lighter wave behind
    final paintLight = Paint()..color = color.withOpacity(0.4)..style = PaintingStyle.fill;
    final pathLight = Path();
    double startYLight = size.height - 240;
    pathLight.moveTo(0, startYLight);
    pathLight.quadraticBezierTo(size.width * 0.25, startYLight - 40 + offset, size.width * 0.5, startYLight);
    pathLight.quadraticBezierTo(size.width * 0.75, startYLight + 40 - offset, size.width, startYLight - 20);
    pathLight.lineTo(size.width, size.height);
    pathLight.lineTo(0, size.height);
    pathLight.close();
    canvas.drawPath(pathLight, paintLight);

    // Main wave
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();
    double startY = size.height - 210;
    path.moveTo(0, startY);
    path.quadraticBezierTo(size.width * 0.25, startY + 40 - offset, size.width * 0.5, startY - 20);
    path.quadraticBezierTo(size.width * 0.75, startY - 60 + offset, size.width, startY);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}

class AnimatedDots extends StatefulWidget {
  const AnimatedDots({super.key});
  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}
class _AnimatedDotsState extends State<AnimatedDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            double value = (_controller.value * 3) - index;
            if (value < 0) value += 3;
            double opacity = 1.0 - (value / 3).clamp(0.0, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(opacity.clamp(0.2, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
