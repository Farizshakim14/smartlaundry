import 'package:flutter/material.dart';
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
  Timer? _autoStopTimer;
  
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  StreamSubscription<QuerySnapshot>? _userSubscription;
  StreamSubscription<QuerySnapshot>? _storeSubscription;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialNotificationLoad = true;

  @override
  void initState() {
    super.initState();
    _setupUserAndStoreListeners();
    _autoStopTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkAndAutoStopMachines();
    });
  }

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    _notificationSubscription?.cancel();
    _userSubscription?.cancel();
    _storeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkAndAutoStopMachines() async {
    if (_selectedStoreId == null) return;
    
    try {
      final snap = await FirebaseFirestore.instance
        .collection('machines')
        .where('store_id', isEqualTo: _selectedStoreId)
        .where('status', isEqualTo: 'Active')
        .where('timer_enabled', isEqualTo: true)
        .get();
        
      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['start_time'] != null && data['duration_minutes'] != null) {
          final startTime = (data['start_time'] as Timestamp).toDate();
          final duration = data['duration_minutes'] as int;
          final endTime = startTime.add(Duration(minutes: duration));
          
          if (DateTime.now().isAfter(endTime)) {
            // Auto stop
            await doc.reference.update({
              'status': 'Idle',
              'timer_enabled': FieldValue.delete(),
              'duration_minutes': FieldValue.delete(),
              'start_time': FieldValue.delete(),
              'payment_method': FieldValue.delete(),
            });
            
            await ActivityService.logActivity(
              storeId: _selectedStoreId,
              action: "Mesin ${data['name']} otomatis berhenti (Waktu habis)",
            );
          }
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  void _setupUserAndStoreListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (user.email == 'farizshakim.14@gmail.com') {
      _userRole = 'Superadmin';
      _setupStoreListener();
    } else {
      _userSubscription?.cancel();
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .snapshots()
          .listen((userDoc) {
        if (userDoc.docs.isNotEmpty) {
          final data = userDoc.docs.first.data();
          final newRole = data['role']?.toString() ?? 'Unknown';
          final newStoreId = data['store_id']?.toString();
          final newName = data['name']?.toString();
          
          bool roleChanged = _userRole != newRole;
          _userRole = newRole;
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
            // Need to fetch stores if role is Owner/Admin/Superadmin
            _setupStoreListener();
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      });
    }
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
        userRole: _userRole ?? 'Unknown',
        selectedStoreId: _selectedStoreId,
        stores: _myStores,
        onStoreChanged: (val) => setState(() => _selectedStoreId = val),
        onViewAllMachines: () => setState(() => _selectedIndex = 1),
      ),
      MachinePage(selectedStoreId: _selectedStoreId, userRole: _userRole ?? 'Unknown'),
      MasterPelangganPage(selectedStoreId: _selectedStoreId),
      StatsPage(selectedStoreId: _selectedStoreId),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.dashboard_rounded, "Home", 0),
              _buildNavItem(Icons.local_laundry_service_rounded, "Mesin", 1),
              _buildNavItem(Icons.people_alt_rounded, "Pelanggan", 2),
              _buildNavItem(Icons.analytics_rounded, "Stats", 3),
              _buildNavItem(Icons.person_rounded, "Profil", 4),
            ],
          ),
        ),
      ),
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

class HomeTab extends StatelessWidget {
  final String? userName;
  final String userRole;
  final String? selectedStoreId;
  final List<Map<String, dynamic>> stores;
  final ValueChanged<String?> onStoreChanged;
  final VoidCallback? onViewAllMachines;

  const HomeTab({
    super.key, 
    this.userName,
    required this.userRole,
    this.selectedStoreId, 
    required this.stores, 
    required this.onStoreChanged,
    this.onViewAllMachines,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedStoreId == null && stores.isEmpty) {
       final isDark = Theme.of(context).brightness == Brightness.dark;
       return SafeArea(
         child: Center(
           child: Padding(
             padding: const EdgeInsets.all(32.0),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Container(
                   padding: const EdgeInsets.all(32),
                   decoration: BoxDecoration(
                     color: const Color(0xFF2563EB).withOpacity(0.1),
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.storefront_outlined, size: 80, color: Color(0xFF2563EB)),
                 ),
                 const SizedBox(height: 32),
                 Text(
                   "Welcome to Workspace!",
                   style: TextStyle(
                     fontSize: 24,
                     fontWeight: FontWeight.bold,
                     color: isDark ? Colors.white : const Color(0xFF1E293B),
                   ),
                 ),
                 const SizedBox(height: 16),
                 Text(
                   "Tampaknya belum ada toko yang terdaftar. Mulailah dengan menambahkan toko pertama Anda untuk mengelola mesin, token, dan memantau transaksi.",
                   textAlign: TextAlign.center,
                   style: TextStyle(
                     fontSize: 16,
                     color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                     height: 1.5,
                   ),
                 ),
                 const SizedBox(height: 40),
                 if (userRole == 'Superadmin' || userRole == 'Admin' || userRole == 'Owner')
                   ElevatedButton.icon(
                     onPressed: () {
                       Navigator.push(
                         context,
                         MaterialPageRoute(builder: (context) => StoreManagementPage(currentRole: userRole)),
                       );
                     },
                     icon: const Icon(Icons.add_business, color: Colors.white),
                     label: const Text("Tambah Toko Baru", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: const Color(0xFF2563EB),
                       padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(16),
                       ),
                       elevation: 0,
                     ),
                   ),
               ],
             ),
           ),
         ),
       );
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 36),
            _buildSubscriptionCards(context),
            const SizedBox(height: 36),
            _buildSectionTitle(context, "Machine Status", "Overview"),
            const SizedBox(height: 16),
            _buildStatusCards(),
            const SizedBox(height: 36),
            _buildSectionTitle(context, "Active Machines", "View All", onTap: onViewAllMachines),
            const SizedBox(height: 16),
            _buildMachineList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F3460);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final displayName = userName ?? user?.displayName ?? "User";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $displayName 👋",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              if (stores.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStoreId,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                      isDense: true,
                      dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 14),
                      onChanged: onStoreChanged,
                      items: stores.map<DropdownMenuItem<String>>((store) {
                        return DropdownMenuItem<String>(
                          value: store['id'],
                          child: Text(store['name']),
                        );
                      }).toList(),
                    ),
                  ),
                )
              else 
                const Text(
                  "Assigned Store",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),

        Row(
          children: [
            if ((userRole == 'Owner' || userRole == 'Cashier') && selectedStoreId != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomerModePage(storeId: selectedStoreId!),
                    ),
                  );
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Icon(Icons.important_devices, color: Colors.white),
                ),
              ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ActivityLogPage(
                      initialStoreId: selectedStoreId,
                      stores: stores,
                      userRole: userRole,
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.04), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Icon(Icons.notifications_none_rounded, color: textColor),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: cardColor, width: 2),
                image: DecorationImage(
                  image: NetworkImage(
                    user?.photoURL ??
                    'https://ui-avatars.com/api/?name=User&background=0F3460&color=fff'
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubscriptionCards(BuildContext context) {
    if (selectedStoreId == 'ALL') {
      return const SizedBox.shrink(); // Hide tokens for 'Semua Toko'
    }

    return StreamBuilder<QuerySnapshot>(
      stream: selectedStoreId != null 
          ? FirebaseFirestore.instance.collection('stores').doc(selectedStoreId).collection('token_batches').where('remaining_tokens', isGreaterThan: 0).snapshots()
          : null,
      builder: (context, snapshot) {
        int tokenBalance = 0;
        List<Map<String, dynamic>> activeBatches = [];

        if (snapshot.hasData) {
           for (var doc in snapshot.data!.docs) {
             final data = doc.data() as Map<String, dynamic>;
             bool isExpired = false;
             DateTime? expiredAt;

             if (data.containsKey('expired_at') && data['expired_at'] != null) {
               expiredAt = (data['expired_at'] as Timestamp).toDate();
               if (DateTime.now().isAfter(expiredAt)) {
                 isExpired = true;
               }
             }

             if (!isExpired) {
               final remaining = data['remaining_tokens'] as int? ?? 0;
               tokenBalance += remaining;
               data['id'] = doc.id;
               data['expired_date'] = expiredAt;
               activeBatches.add(data);
             }
           }
        }

        String masaBerlakuValue = activeBatches.isNotEmpty ? "Detail" : "-";
        String masaBerlakuSubtitle = "${activeBatches.length} Paket Aktif";
        Color masaBerlakuColor = const Color(0xFF10B981);
        IconData masaBerlakuIcon = Icons.list_alt_rounded;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          clipBehavior: Clip.none,
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TokenManagementPage(
                        currentRole: userRole,
                        selectedStoreId: selectedStoreId,
                      ),
                    ),
                  );
                },
                child: AnimatedTokenCard(tokenBalance: tokenBalance),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  if (activeBatches.isNotEmpty) {
                    _showTokenBatchesSheet(context, activeBatches);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada paket token aktif.")));
                  }
                },
                child: _buildInfoCard(
                  context: context,
                  title: "Masa Berlaku",
                  value: masaBerlakuValue,
                  subtitle: masaBerlakuSubtitle,
                  icon: masaBerlakuIcon,
                  iconBgColor: masaBerlakuColor.withOpacity(0.1),
                  iconColor: masaBerlakuColor,
                ),
              ),
              const SizedBox(width: 16),
              StreamBuilder<QuerySnapshot>(
                stream: selectedStoreId != null 
                    ? FirebaseFirestore.instance.collection('transactions')
                        .where('store_id', isEqualTo: selectedStoreId)
                        .snapshots()
                    : null,
                builder: (context, transSnapshot) {
                  int pemakaian = 0;
                  if (transSnapshot.hasData) {
                    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
                    pemakaian = transSnapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
                        final timestamp = data['timestamp'] as Timestamp;
                        return timestamp.toDate().isAfter(thirtyDaysAgo);
                      }
                      return false;
                    }).length;
                  }
                  return _buildInfoCard(
                    context: context,
                    title: "Pemakaian",
                    value: "$pemakaian",
                    subtitle: "30 hari",
                    icon: Icons.insights_rounded,
                    iconBgColor: const Color(0xFFF59E0B).withOpacity(0.1),
                    iconColor: const Color(0xFFF59E0B),
                  );
                }
              ),
            ],
          ),
        );
      }
    );
  }

  void _showTokenBatchesSheet(BuildContext context, List<Map<String, dynamic>> batches) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Detail Token Tersedia", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              ...batches.map((b) {
                final expiredDate = b['expired_date'] as DateTime?;
                final remaining = b['remaining_tokens'];
                final name = b['package_name'] ?? 'Paket Token';
                
                return StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, _) {
                    String subtitle = "Lifetime";
                    if (expiredDate != null) {
                      final diff = expiredDate.difference(DateTime.now());
                      if (diff.inDays > 0) {
                        subtitle = "Sisa ${diff.inDays} Hari (Hingga ${expiredDate.day}/${expiredDate.month}/${expiredDate.year})";
                      } else {
                        final hours = diff.inHours.toString().padLeft(2, '0');
                        final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
                        final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
                        subtitle = "Sisa $hours:$minutes:$seconds (Hingga Pukul ${expiredDate.hour.toString().padLeft(2, '0')}:${expiredDate.minute.toString().padLeft(2, '0')})";
                      }
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.monetization_on, color: Color(0xFF2563EB), size: 36),
                      title: Text("$name ($remaining Token)", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    );
                  }
                );
              }),
            ],
          ),
        );
      }
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1E293B), // Dark Slate
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCards() {
    Query query = FirebaseFirestore.instance.collection('machines');
    if (selectedStoreId != null && selectedStoreId != 'ALL') {
      query = query.where('store_id', isEqualTo: selectedStoreId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int activeCount = 0;
        int idleCount = 0;
        int offlineCount = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? 'Idle';
            if (status == 'Active') activeCount++;
            else if (status == 'Idle') idleCount++;
            else offlineCount++;
          }
        }

        return Row(
          children: [
            Expanded(
              child: _buildSingleCard(
                context: context,
                title: "Active",
                count: activeCount.toString(),
                color: const Color(0xFF10B981),
                icon: Icons.local_laundry_service,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSingleCard(
                context: context,
                title: "Idle",
                count: idleCount.toString(),
                color: const Color(0xFFF59E0B),
                icon: Icons.pause_circle_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSingleCard(
                context: context,
                title: "Offline",
                count: offlineCount.toString(),
                color: const Color(0xFFEF4444),
                icon: Icons.wifi_off,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleCard({required BuildContext context, required String title, required String count, required Color color, required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, String action, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F3460);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: -0.5,
          ),
        ),
        GestureDetector(
          onTap: onTap ?? () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: textColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              action,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMachineList() {
    Query query = FirebaseFirestore.instance.collection('machines');
    if (selectedStoreId != null && selectedStoreId != 'ALL') {
      query = query.where('store_id', isEqualTo: selectedStoreId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No machines added yet.", style: TextStyle(color: Colors.grey)));
        }

        final docs = snapshot.data!.docs;
        
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LiveMachineItem(data: data),
            );
          }).toList(),
        );
      },
    );
  }
}

class LiveMachineItem extends StatefulWidget {
  final Map<String, dynamic> data;

  const LiveMachineItem({super.key, required this.data});

  @override
  State<LiveMachineItem> createState() => _LiveMachineItemState();
}

class _LiveMachineItemState extends State<LiveMachineItem> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = widget.data;
    final name = data['name']?.toString() ?? 'Unknown';
    final rawStatus = data['status']?.toString() ?? 'Idle';
    final type = data['type']?.toString() ?? 'Washer';
    
    Color color = const Color(0xFFF59E0B); // Idle
    double progress = 0.0;
    String timeLeft = "-";
    String status = rawStatus;
    
    if (rawStatus == 'Active') {
      status = type == 'Washer' ? 'Washing' : 'Drying';
      color = type == 'Washer' ? const Color(0xFF2563EB) : const Color(0xFF10B981);
      final timerEnabled = data['timer_enabled'] == true;
      if (timerEnabled && data['start_time'] != null && data['duration_minutes'] != null) {
         final startTime = (data['start_time'] as Timestamp).toDate();
         final durationMins = data['duration_minutes'] as int;
         final endTime = startTime.add(Duration(minutes: durationMins));
         final now = DateTime.now();
         
         if (now.isBefore(endTime)) {
           final diff = endTime.difference(now);
           final totalSecs = durationMins * 60;
           final passedSecs = totalSecs - diff.inSeconds;
           progress = (passedSecs / totalSecs).clamp(0.0, 1.0);
           
           final min = diff.inMinutes;
           final sec = diff.inSeconds % 60;
           timeLeft = "${min}m ${sec}s";
         } else {
           progress = 1.0;
           timeLeft = "0m 0s";
         }
      } else {
         progress = 1.0; 
         timeLeft = "Running";
      }
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (rawStatus == 'Active')
                BoxShadow(
                  color: color.withOpacity(_pulseAnimation.value * 0.4),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 2 * _pulseAnimation.value,
                ),
            ],
            border: rawStatus == 'Active'
                ? Border.all(color: color.withOpacity(_pulseAnimation.value * 0.5), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress > 0 && progress < 1.0)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  if (progress == 1.0)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  Icon(
                    Icons.local_laundry_service,
                    color: color,
                    size: 24,
                  ),
                ],
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                "Time Left",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLeft,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AnimatedTokenCard extends StatefulWidget {
  final int tokenBalance;

  const AnimatedTokenCard({super.key, required this.tokenBalance});

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
              const Text(
                "Sisa Token",
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
