import 'package:aplikasilaundry/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/settings.dart';
import 'package:aplikasilaundry/welcome_page.dart';
import 'package:aplikasilaundry/store_management.dart';
import 'package:aplikasilaundry/user_management.dart';
import 'package:aplikasilaundry/customer_mode.dart';
import 'package:aplikasilaundry/guide.dart';
import 'package:aplikasilaundry/main.dart';
import 'package:aplikasilaundry/editprofile.dart';
import 'package:aplikasilaundry/change_password.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class ProfilePage extends StatefulWidget {
  final String? selectedStoreId;
  const ProfilePage({super.key, this.selectedStoreId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Map<String, Future<DocumentSnapshot>> _storeCache = {};
  bool _notificationsEnabled = true;

  Future<DocumentSnapshot> _getStoreData(String storeId) {
    if (!_storeCache.containsKey(storeId)) {
      _storeCache[storeId] = FirebaseFirestore.instance.collection('stores').doc(storeId).get();
    }
    return _storeCache[storeId]!;
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC), 
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          String currentRole = 'Unknown';
          String currentName = user.displayName ?? "User";
          String? currentStoreId;
          String currentPhone = "-";

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
            currentRole = data['role']?.toString() ?? 'Unknown';
            currentName = data['name']?.toString() ?? currentName;
            currentStoreId = data['store_id']?.toString();
            currentPhone = data['phone']?.toString() ?? "-";
          }

          if (user.email == 'farizshakim.14@gmail.com') {
            currentRole = 'Superadmin';
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. Blue Gradient Header
                Stack(
                  children: [
                    Container(
                      height: 220, 
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -50,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 100,
                      right: 40,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    user.photoURL ?? 'https://ui-avatars.com/api/?name=${currentName.replaceAll(" ", "+")}&background=2563EB&color=fff'
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentName,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email ?? "-",
                                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentRole,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                              },
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.edit, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Content Body
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Card 1: Informasi Akun
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Informasi Akun", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              const SizedBox(height: 16),
                              _buildInfoRow("Nama Lengkap", currentName, isDark),
                              _buildInfoRow("Email", user.email ?? "-", isDark),
                              _buildInfoRow("No. Handphone", currentPhone, isDark),
                              _buildInfoRow("Role", currentRole, isDark),
                              
                              if (currentStoreId != null && currentStoreId.isNotEmpty)
                                FutureBuilder<DocumentSnapshot>(
                                  future: _getStoreData(currentStoreId),
                                  builder: (context, storeSnapshot) {
                                    String storeName = "Loading...";
                                    if (storeSnapshot.hasData && storeSnapshot.data!.exists) {
                                      storeName = (storeSnapshot.data!.data() as Map<String, dynamic>)['name']?.toString() ?? '-';
                                    }
                                    return _buildInfoRow("Cabang Aktif", storeName, isDark, isLast: true);
                                  },
                                )
                              else
                                _buildInfoRow("Cabang Aktif", "Belum ada cabang", isDark, isLast: true),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Card 2: Pengaturan
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Pengaturan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B))),
                              const SizedBox(height: 8),
                              
                              _buildSettingsTile(Icons.person_outline, "Edit Profil", isDark, onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfilePage()));
                              }),
                              _buildSettingsTile(Icons.lock_outline, "Ubah Password", isDark, onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ChangePasswordPage()));
                              }),
                              
                              if (currentRole != 'Cashier')
                                _buildSettingsTile(Icons.storefront_outlined, "Kelola Cabang", isDark, onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => StoreManagementPage(currentRole: currentRole)));
                                }),
                              
                              if (currentRole == 'Superadmin' || currentRole == 'Admin' || currentRole == 'Owner')
                                _buildSettingsTile(Icons.people_alt_outlined, "Kelola User & Role", isDark, onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => UserManagementPage(currentRole: currentRole)));
                                }),
                                
                              if ((widget.selectedStoreId ?? currentStoreId) != null && (widget.selectedStoreId ?? currentStoreId)!.isNotEmpty)
                                _buildSettingsTile(Icons.tablet_android, "Mode Pelanggan", isDark, onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => CustomerModePage(storeId: (widget.selectedStoreId ?? currentStoreId)!)));
                                }),

                              _buildSettingsTile(Icons.menu_book, "Panduan Memakai Aplikasi", isDark, onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => GuidePage(role: currentRole)));
                              }),
                              
                              _buildSettingsTile(
                                Icons.notifications_none, 
                                "Pengaturan Notifikasi", 
                                isDark,
                                trailing: Switch(
                                  value: _notificationsEnabled, 
                                  onChanged: (val) {
                                    setState(() {
                                      _notificationsEnabled = val;
                                    });
                                    CustomSnackbar.show(context, 
                                      SnackBar(content: Text(val ? "Notifikasi Diaktifkan" : "Notifikasi Dinonaktifkan")),
                                    );
                                  }, 
                                  activeColor: const Color(0xFF4F46E5),
                                ),
                                onTap: () {
                                  setState(() {
                                    _notificationsEnabled = !_notificationsEnabled;
                                  });
                                  CustomSnackbar.show(context, 
                                    SnackBar(content: Text(_notificationsEnabled ? "Notifikasi Diaktifkan" : "Notifikasi Dinonaktifkan")),
                                  );
                                }
                              ),
                              
                              _buildSettingsTile(
                                Icons.dark_mode_outlined, 
                                "Tema", 
                                isDark,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 16, color: const Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(isDark ? "Dark" : "Light", style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFF64748B)),
                                  ],
                                ),
                                onTap: () {
                                  themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                                },
                                isLast: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Card 3: Logout
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4))],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () async {
                                try {
                                  try {
                                    await GoogleSignIn().signOut();
                                  } catch (e) {
                                    print("GoogleSignIn logout error: $e");
                                  }
                                  await FirebaseAuth.instance.signOut();
                                  if(mounted) {
                                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomePage()), (route) => false);
                                  }
                                } catch (e) {
                                  print("Logout error: $e");
                                }
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, color: Color(0xFFEF4444)),
                                    SizedBox(width: 16),
                                    Text("Logout", style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(
              value, 
              textAlign: TextAlign.right,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, bool isDark, {required VoidCallback onTap, Widget? trailing, bool isLast = false}) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: const Color(0xFF64748B)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(title, style: TextStyle(color: isDark ? Colors.grey[300] : const Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                  trailing ?? const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(color: isDark ? Colors.grey[800] : const Color(0xFFF1F5F9), height: 1),
      ],
    );
  }
}

