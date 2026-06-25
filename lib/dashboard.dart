import 'package:aplikasilaundry/live_machine_item.dart';
import 'package:flutter/material.dart';
import 'package:aplikasilaundry/localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:aplikasilaundry/machine.dart';
import 'package:aplikasilaundry/stats.dart';
import 'package:aplikasilaundry/profile.dart';
import 'package:aplikasilaundry/masterpelanggan.dart';
import 'package:aplikasilaundry/activity_log.dart';
import 'package:aplikasilaundry/activity_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aplikasilaundry/token_management.dart';
import 'package:aplikasilaundry/store_management.dart';
import 'package:aplikasilaundry/customer_mode.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:aplikasilaundry/home_tab.dart';
import 'package:aplikasilaundry/push_notification_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  String? _userRole;
  String? _userName;
  String? _selectedStoreId;
  List<Map<String, dynamic>> _myStores = [];
  bool _isLoading = true;
  
  String? _currentSessionId;
  
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _storeSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialNotificationLoad = true;

  String get _effectiveRole {
    if (_userRole == 'Superadmin' && _selectedStoreId != 'ALL' && _selectedStoreId != null) {
      return 'Owner';
    }
    return _userRole ?? 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _setupUserAndStoreListeners();
    
    // Inisialisasi Push Notification setelah login berhasil
    PushNotificationService.initialize();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _userSubscription?.cancel();
    _storeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _setupUserAndStoreListeners() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // Update Session ID saat dashboard pertama kali dibuka secara sinkron agar listener tidak mendeteksi id lama
    try {
      final snap = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({'session_id': _currentSessionId});
      }
    } catch (e) {
      debugPrint("Error updating session: $e");
    }

    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: user.email)
        .limit(1)
        .snapshots()
        .listen((userDoc) {
      if (userDoc.docs.isNotEmpty) {
        final data = userDoc.docs.first.data();
        
        // --- LOGIC SINGLE DEVICE LOGIN ---
        if (data['session_id'] != null && data['session_id'] != _currentSessionId) {
          FirebaseAuth.instance.signOut();
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text("Sesi Berakhir"),
                content: const Text("Akun ini telah login di perangkat lain."),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
            );
          }
          return; // Hentikan proses selanjutnya karena akan logout
        }

        final newRole = data['role']?.toString() ?? 'Unknown';
        final newStoreId = data['store_id']?.toString();
        final newName = data['name']?.toString();
        
        bool roleChanged = _userRole != newRole;
        
        // Prioritas role superadmin jika email cocok
        if (user.email == 'farizshakim.14@gmail.com') {
          _userRole = 'Superadmin';
        } else {
          _userRole = newRole;
        }

        if (newName != null && newName.isNotEmpty) {
          _userName = newName;
        }

        if (_userRole == 'Cashier') {
          _selectedStoreId = newStoreId;
          _myStores = [];
          _storeSubscription?.cancel();
          if (mounted) {
            setState(() => _isLoading = false);
            if (roleChanged) _setupNotificationListener();
          }
        } else {
          // Fetch stores if role is Owner/Admin/Superadmin
          _setupStoreListener();
        }
      } else {
        // Fallback jika tidak ada dokumen tapi email superadmin
        if (user.email == 'farizshakim.14@gmail.com') {
          _userRole = 'Superadmin';
          _setupStoreListener();
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    });
  }

  void _setupStoreListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Query storesQuery = FirebaseFirestore.instance.collection('stores');
    if (_userRole == 'Owner' || (_userRole != 'Superadmin' && _userRole != 'Admin' && _userRole != 'Cashier')) {
      storesQuery = storesQuery.where('owner_email', isEqualTo: user.email);
    }

    _storeSubscription?.cancel();
    _storeSubscription = storesQuery.snapshots().listen((storesSnap) {
      final newStores = storesSnap.docs
          .map((d) => {'id': d.id, 'name': (d.data() as Map<String, dynamic>)['name']})
          .toList();
      
      if (_userRole == 'Superadmin' || _userRole == 'Admin') {
        newStores.insert(0, {'id': 'ALL', 'name': 'Semua Toko'});
      }
      
      if (mounted) {
        setState(() {
          _myStores = newStores;
          // Check if selectedStoreId is still valid
          if (_myStores.isNotEmpty) {
            if (_selectedStoreId == null || !_myStores.any((s) => s['id'] == _selectedStoreId)) {
              _selectedStoreId = _myStores.first['id'];
            }
          } else {
            _selectedStoreId = null;
          }
          _isLoading = false;
        });
        _setupNotificationListener(); 
      }
    });
  }

  void _setupNotificationListener() {
    _notificationSubscription?.cancel();

    // Gunakan koleksi 'activities' yang benar
    Query query = FirebaseFirestore.instance.collection('activities');
    
    // HANYA gunakan index pada timestamp untuk menghindari error Composite Index di Firebase
    final now = Timestamp.now();
    query = query.where('timestamp', isGreaterThanOrEqualTo: now).orderBy('timestamp', descending: true);

    _notificationSubscription = query.snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          // Mencegah trigger dari cache lokal (saat timestamp masih null)
          if (data['timestamp'] == null) continue;

          // FILTER LOKAL: Menghindari kebutuhan Composite Index di Firebase
          final String storeId = data['store_id']?.toString() ?? 'GLOBAL';
          if (_userRole == 'Cashier' && storeId != _selectedStoreId) continue;
          if (_userRole == 'Owner') {
            List<String> myStoreIds = _myStores.map((s) => s['id'] as String).toList();
            if (myStoreIds.isNotEmpty && !myStoreIds.contains(storeId)) continue;
            if (myStoreIds.isEmpty) continue; // Owner tidak punya toko, jangan tampilkan apa-apa
          }
          
          _playNotificationSound();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(data['action'] ?? 'Notifikasi Baru')),
                  ],
                ),
                backgroundColor: const Color(0xFF0F3460),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    });
  }

  void _playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('notification.mp3'));
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), body: const Center(child: CircularProgressIndicator()));
    }

    final List<Widget> pages = [
      HomeTab(
        userName: _userName,
        userRole: _effectiveRole,
        selectedStoreId: _selectedStoreId,
        stores: _myStores,
        onStoreChanged: (val) => setState(() => _selectedStoreId = val),
        onViewAllMachines: () => setState(() => _selectedIndex = 1),
      ),
      MachinePage(selectedStoreId: _selectedStoreId, userRole: _effectiveRole),
      MasterPelangganPage(selectedStoreId: _selectedStoreId),
      StatsPage(selectedStoreId: _selectedStoreId, userRole: _effectiveRole, myStores: _myStores),
      ProfilePage(selectedStoreId: _selectedStoreId),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(Icons.home_rounded, "Home", 0),
              _buildNavItem(Icons.local_laundry_service_rounded, AppLocalizations.tr('machine'), 1),
              _buildFabItem(),
              _buildNavItem(Icons.analytics_rounded, AppLocalizations.tr('stats'), 3),
              _buildNavItem(Icons.person_rounded, AppLocalizations.tr('profile'), 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabItem() {
    return GestureDetector(
      onTap: _showTransactionBottomSheet,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4338CA), // Indigo/Blue color like mockup
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4338CA).withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 4),
          Text(AppLocalizations.tr('transaction'),
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.only(top: 24, bottom: 32, left: 24, right: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.tr('create_transaction'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F3460),
                ),
              ),
              const SizedBox(height: 24),
              _buildSheetItem(
                icon: Icons.local_laundry_service_outlined,
                title: AppLocalizations.tr('wash_only'),
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerModePage(storeId: _selectedStoreId!)));
                },
              ),
              _buildSheetItem(
                icon: Icons.local_fire_department_outlined,
                title: AppLocalizations.tr('dry_only'),
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerModePage(storeId: _selectedStoreId!)));
                },
              ),
              _buildSheetItem(
                icon: Icons.layers_outlined,
                title: AppLocalizations.tr('combo_package'),
                color: Colors.purple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerModePage(storeId: _selectedStoreId!)));
                },
              ),
              const Divider(height: 32),
              _buildSheetItem(
                icon: Icons.person_add_outlined,
                title: AppLocalizations.tr('new_customer'),
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _selectedIndex = 2); // Beralih ke tab Master Pelanggan
                },
              ),
              _buildSheetItem(
                icon: Icons.queue_outlined,
                title: AppLocalizations.tr('add_to_queue'),
                color: Colors.indigo,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerModePage(storeId: _selectedStoreId!)));
                },
              ),
              _buildSheetItem(
                icon: Icons.account_balance_wallet_outlined,
                title: AppLocalizations.tr('top_up_token'),
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TokenManagementPage(
                        currentRole: _effectiveRole,
                        selectedStoreId: _selectedStoreId,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  ),
                  child: Text(
                    AppLocalizations.tr('close'),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetItem({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;
    final activeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F3460);
    final color = isSelected ? activeColor : const Color(0xFF94A3B8);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AnimatedTokenCard extends StatefulWidget {
  final int tokenBalance;
  final String? title;

  const AnimatedTokenCard({super.key, required this.tokenBalance, this.title});

  @override
  State<AnimatedTokenCard> createState() => _AnimatedTokenCardState();
}

class _AnimatedTokenCardState extends State<AnimatedTokenCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Ubah batas sisa token "hampir habis" sesuai kebutuhan.
  final int lowThreshold = 20;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _checkBalance();
  }

  @override
  void didUpdateWidget(AnimatedTokenCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tokenBalance != widget.tokenBalance) {
      _checkBalance();
    }
  }

  void _checkBalance() {
    if (widget.tokenBalance < lowThreshold) {
      _controller.repeat(reverse: true);
    } else {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLow = widget.tokenBalance < lowThreshold;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final glowColor = Colors.redAccent.withOpacity(_animation.value * 0.5);
        final defaultIconBgColor = const Color(0xFF0F3460).withOpacity(0.1);
        final defaultIconColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F3460);
        
        final iconBgColor = isLow ? Colors.red.withOpacity(0.1 + (_animation.value * 0.2)) : defaultIconBgColor;
        final iconColor = isLow ? Colors.redAccent : defaultIconColor;

        return Container(
          width: 150,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isLow ? glowColor : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: isLow ? 20 * _animation.value + 10 : 20,
                spreadRadius: isLow ? 5 * _animation.value : 0,
                offset: isLow ? Offset.zero : const Offset(0, 10),
              ),
            ],
            border: isLow ? Border.all(color: Colors.redAccent.withOpacity(_animation.value * 0.6), width: 1.5) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isLow ? Icons.warning_amber_rounded : Icons.monetization_on_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "${widget.tokenBalance}",
                style: TextStyle(
                  color: isLow ? Colors.redAccent : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.title ?? AppLocalizations.tr('token_balance'),
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isLow ? "Segera Isi Ulang!" : "Ketuk kelola",
                style: TextStyle(
                  color: isLow ? Colors.redAccent : const Color(0xFF94A3B8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
