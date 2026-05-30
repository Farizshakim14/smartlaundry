import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/settings.dart';
import 'package:aplikasilaundry/welcome_page.dart';
import 'package:aplikasilaundry/store_management.dart';
import 'package:aplikasilaundry/user_management.dart';
import 'package:aplikasilaundry/customer_mode.dart';
import 'package:aplikasilaundry/guide.dart';
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

  Future<DocumentSnapshot> _getStoreData(String storeId) {
    if (!_storeCache.containsKey(storeId)) {
      _storeCache[storeId] = FirebaseFirestore.instance.collection('stores').doc(storeId).get();
    }
    return _storeCache[storeId]!;
  }

  Future<String> _getUserRole(String? email) async {
    if (email == 'farizshakim.14@gmail.com') {
      return 'Superadmin';
    }
    if (email == null || email.isEmpty) {
      return 'Unknown';
    }
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data()['role']?.toString() ?? 'Unknown';
      }
    } catch (e) {
      print("Error fetching role: $e");
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const SizedBox();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "My Profile",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: user.email)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                String currentRole = 'Unknown';
                String currentName = user.displayName ?? "User";
                String? currentStoreId;

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  currentRole = data['role']?.toString() ?? 'Unknown';
                  currentName = data['name']?.toString() ?? currentName;
                  currentStoreId = data['store_id']?.toString();
                }

                if (user.email == 'farizshakim.14@gmail.com') {
                  currentRole = 'Superadmin';
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // Header Profil
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF2563EB), width: 3),
                                image: DecorationImage(
                                  image: NetworkImage(
                                    user.photoURL ??
                                    'https://ui-avatars.com/api/?name=${currentName.replaceAll(" ", "+")}&background=2563EB&color=fff'
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (currentStoreId != null && currentStoreId.isNotEmpty)
                              FutureBuilder<DocumentSnapshot>(
                                future: _getStoreData(currentStoreId),
                                builder: (context, storeSnapshot) {
                                  if (storeSnapshot.hasData && storeSnapshot.data!.exists) {
                                    final storeData = storeSnapshot.data!.data() as Map<String, dynamic>;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4.0),
                                      child: Text(
                                        (storeData['name'] ?? '').toString().toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            Text(
                              currentName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email ?? "-",
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                currentRole,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Administrasi
                      _buildMenuSection("Administration", [
                        if (currentRole == 'Superadmin' || currentRole == 'Admin' || currentRole == 'Owner') ...[
                          _buildMenuItem(
                            Icons.people_alt_outlined, 
                            "User Management", 
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserManagementPage(currentRole: currentRole),
                                ),
                              );
                            }
                          ),
                        ],
                        if (currentRole != 'Cashier') ...[
                          _buildMenuItem(
                            Icons.storefront_outlined, 
                            "Store Management", 
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StoreManagementPage(currentRole: currentRole),
                                ),
                              );
                            }
                          ),
                        ],
                      ], isDark),

                      // Layanan (Self-Service)
                      if ((widget.selectedStoreId ?? currentStoreId) != null && (widget.selectedStoreId ?? currentStoreId)!.isNotEmpty)
                        _buildMenuSection("Layanan", [
                          _buildMenuItem(
                            Icons.tablet_android, 
                            "Mode Pelanggan (Self-Service)", 
                            isDark: isDark,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CustomerModePage(storeId: (widget.selectedStoreId ?? currentStoreId)!),
                                ),
                              );
                            }
                          ),
                        ], isDark),

                      // Pengaturan
                      _buildMenuSection("Settings", [
                        _buildMenuItem(Icons.settings_outlined, "Pengaturan Akun & Aplikasi", isDark: isDark, onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsPage()),
                          );
                        }),
                      ], isDark),

                      // Lainnya
                      _buildMenuSection("Other", [
                        _buildMenuItem(
                          Icons.menu_book, 
                          "Panduan Memakai Aplikasi", 
                          isDark: isDark, 
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GuidePage(role: currentRole),
                              ),
                            );
                          }
                        ),
                        _buildMenuItem(Icons.help_outline, "Help & Support", isDark: isDark, onTap: () {}),
                        _buildMenuItem(
                          Icons.logout,
                          "Logout",
                          color: const Color(0xFFEF4444),
                          isDark: isDark,
                          onTap: () async {
                            try {
                              try {
                                await GoogleSignIn().signOut(); // 🔥 Sign out from Google
                              } catch (e) {
                                print("Google Sign Out error: $e");
                              }
                              await FirebaseAuth.instance.signOut(); // 🔥 Sign out from Firebase
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => const WelcomePage()),
                                (route) => false,
                              );
                            } catch (e) {
                              print("Logout error: $e");
                            }
                          },
                        ),
                      ], isDark),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildMenuSection(String title, List<Widget> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {String? trailing, Color? color, required VoidCallback onTap, required bool isDark}) {
    final itemColor = color ?? (isDark ? Colors.white : const Color(0xFF1E293B));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: itemColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: itemColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: itemColor,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            if (trailing == null && color == null)
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
