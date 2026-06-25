import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

class TokenManagementPage extends StatefulWidget {
  final String currentRole;
  final String? selectedStoreId;

  const TokenManagementPage({super.key, required this.currentRole, this.selectedStoreId});

  @override
  State<TokenManagementPage> createState() => _TokenManagementPageState();
}

class _TokenManagementPageState extends State<TokenManagementPage> with SingleTickerProviderStateMixin {
  final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  late TabController _tabController;

  bool get isAdmin => widget.currentRole == 'Superadmin' || widget.currentRole == 'Admin';
  Map<String, dynamic>? _selectedPackage;

  @override
  void initState() {
    super.initState();
    // Admin punya 2 tab: Paket dan Request. Owner/Cashier cuma 1 tab.
    _tabController = TabController(length: isAdmin ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddTokenPackageDialog() {
    if (!isAdmin) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddTokenPackageForm(),
    ).then((newPackage) async {
      if (newPackage != null) {
        await FirebaseFirestore.instance.collection('token_packages').add({
          ...newPackage,
          'created_at': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paket "${newPackage['name']}" berhasil ditambahkan!'),
              backgroundColor: const Color(0xFF10B981), // Emerald
            ),
          );
        }
      }
    });
  }

  void _showManualTransferDialog(Map<String, dynamic> package) {
    showDialog(
      context: context,
      builder: (context) => ManualTransferDialog(
        package: package,
        storeId: widget.selectedStoreId!,
        onSuccess: () {
          _showSuccessDialog("Permintaan Terkirim!", "Bukti transfer telah dicatat. Menunggu persetujuan Admin.");
        },
      ),
    );
  }

  void _confirmBuyToken(Map<String, dynamic> package) {
    if (widget.selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Toko belum dipilih. Pilih toko terlebih dahulu di Dashboard.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
        final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text(
                        "Detail Pembelian",
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ringkasan Paket
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.stars, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(package['name'], style: TextStyle(color: subTextColor, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${package['tokens']} Token",
                                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              currencyFormatter.format(package['price']),
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text("Pilih Metode", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      
                      // Tombol Midtrans
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _processBuyToken(package, 'Midtrans');
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            color: const Color(0xFF10B981).withOpacity(0.05),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("QRIS (Langsung)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                    Text("Bayar langsung dengan scan QRIS", style: TextStyle(fontSize: 12, color: subTextColor)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF10B981)),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Tombol Transfer Manual
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showManualTransferDialog(package);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.account_balance_wallet, color: subTextColor, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Transfer Manual", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                    Text("Verifikasi oleh Admin", style: TextStyle(fontSize: 12, color: subTextColor)),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Batal
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey, fontSize: 16)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processBuyToken(Map<String, dynamic> package, String method) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final storeId = widget.selectedStoreId!;
      final tokensToAdd = package['tokens'] as int;

      if (method == 'Midtrans') {
        // Panggil backend Node.js untuk mendapatkan Snap Token / Redirect URL Midtrans
        // PENTING: Ganti IP 192.168.x.x dengan IP komputer/server Node.js Anda
        // Jika menggunakan HP fisik, pastikan 1 jaringan WiFi dengan PC dan gunakan IPv4 PC (contoh 192.168.1.10).
        // Jika pakai emulator Android, bisa coba 10.0.2.2
        const String serverUrl = 'http://103.150.226.111:3000/pay';
        
        final response = await http.post(
          Uri.parse(serverUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'price': package['price'],
            'store_id': storeId,
            'package_name': package['name'],
            'tokens': tokensToAdd,
            'valid_days': package['valid_days'] ?? 0,
          }),
        );

        if (mounted) {
          Navigator.pop(context); // Tutup loading
        }

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final qrUrl = responseData['qr_url'];
          final orderId = responseData['order_id'];
          
          if (qrUrl != null && orderId != null) {
              if (mounted) {
                // Siapkan listener Firestore sebelum membuka dialog
                StreamSubscription<DocumentSnapshot>? sub;
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Scan QRIS untuk Membayar", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                'http://103.150.226.111:3000/proxy-qr?url=${Uri.encodeComponent(qrUrl)}', 
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Text("Gagal memuat QR Code", textAlign: TextAlign.center));
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: qrUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('URL QR berhasil disalin! (Gunakan untuk download/testing)')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text("Salin URL QR (Khusus Testing)", style: TextStyle(fontSize: 12)),
                          ),
                          const SizedBox(height: 16),
                          const Text("Menunggu Pembayaran...", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text("Silakan scan QR Code di atas menggunakan aplikasi e-Wallet atau m-Banking Anda.\n\nSaldo token toko akan otomatis bertambah setelah pembayaran sukses dikonfirmasi.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Tutup Jendela Ini"),
                          )
                        ],
                      ),
                    );
                  }
                ).then((_) {
                  // Batalkan listener jika dialog ditutup manual
                  sub?.cancel();
                });

                // Mulai listen status pembayaran
                sub = FirebaseFirestore.instance.collection('token_requests').doc(orderId).snapshots().listen((doc) {
                  if (doc.exists && doc.data() != null) {
                    final data = doc.data() as Map<String, dynamic>;
                    if (data['status'] == 'Approved') {
                      sub?.cancel();
                      if (mounted) {
                        Navigator.pop(context); // Tutup dialog QR
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran berhasil! Token ditambahkan.'), backgroundColor: Colors.green),
                        );
                      }
                    } else if (data['status'] == 'Failed') {
                      sub?.cancel();
                      if (mounted) {
                        Navigator.pop(context); // Tutup dialog QR
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pembayaran dibatalkan atau kedaluwarsa.'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                });
              }
          } else {
            throw 'Gagal mendapatkan QRIS dari server.';
          }
        } else {
          throw 'Error dari server: ${response.statusCode}';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveRequest(String requestId, String storeId, int tokensToAdd, int validDays) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Tambah batch token ke toko tersebut
      final batchesRef = FirebaseFirestore.instance.collection('stores').doc(storeId).collection('token_batches');
      
      DateTime? expiredAt;
      if (validDays > 0) {
        expiredAt = DateTime.now().add(Duration(days: validDays));
      }
      
      final reqDoc = await FirebaseFirestore.instance.collection('token_requests').doc(requestId).get();
      String pkgName = "Paket Token";
      if (reqDoc.exists) {
        final data = reqDoc.data();
        if (data != null && data['package_name'] != null) {
            pkgName = data['package_name'];
        }
      }

      await batchesRef.add({
        'package_name': pkgName,
        'original_tokens': tokensToAdd,
        'remaining_tokens': tokensToAdd,
        'expired_at': expiredAt != null ? Timestamp.fromDate(expiredAt) : null,
        'purchased_at': FieldValue.serverTimestamp(),
      });

      // 2. Ubah status request jadi Approved
      await FirebaseFirestore.instance.collection('token_requests').doc(requestId).update({
        'status': 'Approved',
      });

      if (mounted) {
        Navigator.pop(context); // loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request berhasil di-approve!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal approve: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    await FirebaseFirestore.instance.collection('token_requests').doc(requestId).update({
      'status': 'Rejected',
    });
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text("Tutup", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      )
    );
  }

  void _deletePackage(String docId) async {
    await FirebaseFirestore.instance.collection('token_packages').doc(docId).delete();
  }

  Future<Map<String, int>> _fetchHeaderStats() async {
    int saldoSistem = 0;
    int totalTransaksi = 0;
    int pendingRequest = 0;
    int approvedRequest = 0;

    try {
      // 1. Saldo Sistem (Total remaining_tokens dari semua toko)
      final batchesSnap = await FirebaseFirestore.instance.collectionGroup('token_batches').get();
      for (var doc in batchesSnap.docs) {
        saldoSistem += (doc.data()['remaining_tokens'] ?? 0) as int;
      }

      // 2. Total Transaksi Hari Ini
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final txSnap = await FirebaseFirestore.instance.collection('transactions')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();
      totalTransaksi = txSnap.docs.length;

      // 3. Pending & Approved Request
      final reqSnap = await FirebaseFirestore.instance.collection('token_requests').get();
      for (var doc in reqSnap.docs) {
        final status = doc.data()['status'];
        if (status == 'Pending') pendingRequest++;
        if (status == 'Approved') approvedRequest++;
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }

    return {
      'saldoSistem': saldoSistem,
      'totalTransaksi': totalTransaksi,
      'pendingRequest': pendingRequest,
      'approvedRequest': approvedRequest,
    };
  }

  Widget _buildBlueHeader() {
    return FutureBuilder<Map<String, int>>(
      future: _fetchHeaderStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'saldoSistem': 0, 'totalTransaksi': 0, 'pendingRequest': 0, 'approvedRequest': 0};
        
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Saldo Sistem", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF59E0B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  NumberFormat.decimalPattern('id').format(stats['saldoSistem']),
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(width: 4),
                                const Text("Token", style: TextStyle(color: Colors.grey, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Total Transaksi Hari Ini", style: TextStyle(color: Colors.grey, fontSize: 11)),
                                const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${stats['totalTransaksi']}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.white,
                          child: Image.asset('assets/machine_card_icon.png', fit: BoxFit.contain, height: 130),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.access_time_filled, color: Color(0xFF8B5CF6)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Pending Request", style: TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text("${stats['pendingRequest']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const Text("Request", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Disetujui", style: TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text("${stats['approvedRequest']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const Text("Request", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Future<Map<String, dynamic>> _fetchOwnerTokens() async {
    if (widget.selectedStoreId == null) return {'total': 0, 'expired_at': null};
    int total = 0;
    DateTime? maxExpiry;
    final snap = await FirebaseFirestore.instance.collection('stores').doc(widget.selectedStoreId).collection('token_batches').get();
    for (var doc in snap.docs) {
      final rem = (doc.data()['remaining_tokens'] ?? 0) as int;
      if (rem > 0) {
        bool isExpired = false;
        final exp = doc.data()['expired_at'] as Timestamp?;
        if (exp != null) {
          if (DateTime.now().isAfter(exp.toDate())) {
            isExpired = true;
          }
        }

        if (!isExpired) {
          total += rem;
          if (exp != null) {
            if (maxExpiry == null || exp.toDate().isAfter(maxExpiry!)) {
              maxExpiry = exp.toDate();
            }
          }
        }
      }
    }
    return {'total': total, 'expired_at': maxExpiry};
  }

  Widget _buildOwnerTokenPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text("Token Saya", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: widget.selectedStoreId == null
        ? const Center(child: Text("Toko belum dipilih. Silakan pilih toko di Dashboard."))
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Biru Token Saya
                      FutureBuilder<Map<String, dynamic>>(
                        future: _fetchOwnerTokens(),
                        builder: (context, snapshot) {
                          final data = snapshot.data ?? {'total': 0, 'expired_at': null};
                          final expiryDate = data['expired_at'] as DateTime?;
                          final expiryStr = expiryDate != null ? DateFormat('dd MMMM yyyy', 'id').format(expiryDate) : 'Lifetime';
                          
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                            child: const Icon(Icons.stars, color: Colors.white, size: 20),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text("Token Saya", style: TextStyle(color: Colors.white, fontSize: 16)),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text("${data['total']}", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1)),
                                          const SizedBox(width: 8),
                                          const Padding(
                                            padding: EdgeInsets.only(bottom: 6),
                                            child: Text("Token", style: TextStyle(color: Colors.white70, fontSize: 16)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                                          const SizedBox(width: 6),
                                          Text("Berakhir: $expiryStr", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Image.asset('assets/machine_card_icon.png', width: 100, fit: BoxFit.contain),
                              ],
                            ),
                          );
                        }
                      ),
                      
                      const SizedBox(height: 32),
                      Text("Pilih Paket Token", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // List Paket Token
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('token_packages').orderBy('created_at', descending: true).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final packages = snapshot.data!.docs;
                          
                          return Column(
                            children: packages.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final packageId = doc.id;
                              final name = data['name']?.toString() ?? 'Paket';
                              final tokens = data['tokens'] as int? ?? 0;
                              final price = data['price'] as int? ?? 0;
                              final validDays = data['valid_days'] as int? ?? 0;
                              
                              final isSelected = _selectedPackage != null && _selectedPackage!['id'] == packageId;
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPackage = {
                                      'id': packageId,
                                      'name': name,
                                      'tokens': tokens,
                                      'price': price,
                                      'valid_days': validDays,
                                    };
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: isSelected ? 2 : 1),
                                    boxShadow: [
                                      if (isSelected) BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.local_laundry_service, color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF94A3B8), size: 28),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(name, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text("$tokens Token", style: const TextStyle(color: Color(0xFF6366F1), fontSize: 14, fontWeight: FontWeight.bold)),
                                                const SizedBox(width: 8),
                                                Text("•  ${validDays > 0 ? '$validDays Hari' : 'Lifetime'}", style: TextStyle(color: subTextColor, fontSize: 12)),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(currencyFormatter.format(price), style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      Radio<String>(
                                        value: packageId,
                                        groupValue: _selectedPackage?['id'],
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedPackage = {
                                              'id': packageId,
                                              'name': name,
                                              'tokens': tokens,
                                              'price': price,
                                              'valid_days': validDays,
                                            };
                                          });
                                        },
                                        activeColor: const Color(0xFF6366F1),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        }
                      ),
                      
                      const SizedBox(height: 16),
                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Informasi", style: TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text("Token akan langsung masuk setelah pembayaran berhasil dikonfirmasi.", style: TextStyle(color: Color(0xFF1E3A8A), fontSize: 12)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              // Bottom Nav
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
                  ],
                ),
                child: SafeArea(
                  child: ElevatedButton(
                    onPressed: _selectedPackage == null ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentDetailsPage(
                            package: _selectedPackage!,
                            storeId: widget.selectedStoreId!,
                            onProcessBuyToken: (pkg, method) {
                              Navigator.pop(context); // Tutup PaymentDetailsPage
                              _processBuyToken(pkg, method);
                            },
                            onShowManualTransfer: (pkg) {
                              Navigator.pop(context); // Tutup PaymentDetailsPage
                              _showManualTransferDialog(pkg);
                            },
                          )
                        )
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF94A3B8),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Lanjutkan Pembayaran", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin) {
      return _buildOwnerTokenPage();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: isAdmin ? const Color(0xFF2563EB) : cardColor,
              elevation: 0,
              pinned: true,
              title: Text(
                "Token Management",
                style: TextStyle(color: isAdmin ? Colors.white : textColor, fontWeight: FontWeight.bold),
              ),
              iconTheme: IconThemeData(color: isAdmin ? Colors.white : textColor),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_none),
                  onPressed: () {},
                )
              ],
            ),
            if (isAdmin)
              SliverToBoxAdapter(
                child: _buildBlueHeader(),
              ),
            if (isAdmin)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: "Paket Token"),
                      Tab(text: "Approval Request"),
                    ],
                  ),
                  color: bgColor,
                ),
              ),
          ];
        },
        body: isAdmin ? TabBarView(
          controller: _tabController,
          children: [
            _buildPackageList(),
            _buildRequestList(),
          ],
        ) : _buildPackageList(),
      ),
      floatingActionButton: (isAdmin && _tabController.index == 0)
          ? FloatingActionButton.extended(
              onPressed: _showAddTokenPackageDialog,
              backgroundColor: const Color(0xFF2563EB), // Primary Blue
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text("Buat Paket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildPackageList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('token_packages').orderBy('price').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  "Belum ada Paket Token",
                  style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        final packages = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: packages.length,
          itemBuilder: (context, index) {
            final doc = packages[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final name = data['name']?.toString() ?? 'Paket';
            final tokens = data['tokens'] as int? ?? 0;
            final price = data['price'] as int? ?? 0;

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
            final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
            final subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey[600]!;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_laundry_service, color: Color(0xFF8B5CF6), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              "$tokens Token",
                              style: const TextStyle(color: Color(0xFF2563EB), fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: Text(
                                "  •  ${data['valid_days'] != null && data['valid_days'] > 0 ? 'Berlaku ${data['valid_days']} Hari' : 'Lifetime'}",
                                style: TextStyle(color: subTextColor, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(price),
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: subTextColor),
                      onSelected: (value) {
                        if (value == 'delete') {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Hapus Paket"),
                              content: Text("Yakin ingin menghapus paket '$name'?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _deletePackage(doc.id);
                                  }, 
                                  child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Hapus Paket", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _confirmBuyToken(data),
                      child: const Text("Beli", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : Colors.grey[600]!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('token_requests')
          .where('status', isEqualTo: 'Pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Tidak ada request yang menunggu.", style: TextStyle(color: subTextColor)));
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final doc = requests[index];
            final data = doc.data() as Map<String, dynamic>;
            final storeId = data['store_id']?.toString() ?? '';
            final packageName = data['package_name']?.toString() ?? 'Paket Token';
            final tokens = data['tokens'] as int? ?? 0;
            final price = data['price'] as int? ?? 0;
            final method = data['method']?.toString() ?? '-';
            final proofUrl = data['proof_url'] as String?;
            final validDays = data['valid_days'] as int? ?? 0;

            // Kita bisa ngambil nama toko kalau mau, tapi untuk simplifikasi kita tampilkan storeId.
            return FutureBuilder<DocumentSnapshot>(
              future: storeId.isNotEmpty ? FirebaseFirestore.instance.collection('stores').doc(storeId).get() : null,
              builder: (context, storeSnapshot) {
                String storeName = storeId.isEmpty ? 'Unknown Store' : storeId; // fallback
                if (storeSnapshot.hasData && storeSnapshot.data!.exists) {
                  final storeData = storeSnapshot.data!.data() as Map<String, dynamic>?;
                  if (storeData != null && storeData.containsKey('name')) {
                    storeName = storeData['name']?.toString() ?? storeName;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                      // Header Card
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_laundry_service, color: Color(0xFF8B5CF6), size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        packageName,
                                        style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        "PENDING",
                                        style: TextStyle(color: Color(0xFFD97706), fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$tokens Token",
                                  style: const TextStyle(color: Color(0xFF2563EB), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Details
                      _buildDetailRow(Icons.storefront_outlined, "Nama Toko", storeName, isDark),
                      _buildDetailRow(Icons.payment_outlined, "Metode", method, isDark),
                      _buildDetailRow(Icons.monetization_on_outlined, "Harga", currencyFormatter.format(price), isDark),
                      _buildDetailRow(Icons.access_time, "Masa Berlaku", validDays > 0 ? '$validDays Hari' : 'Lifetime', isDark),
                  
                  if (proofUrl != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Stack(
                              children: [
                                Image.network(proofUrl, fit: BoxFit.contain),
                                Positioned(
                                  top: 8, right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, shadows: [Shadow(blurRadius: 10)]),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                )
                              ],
                            )
                          )
                        );
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.image_outlined, color: Color(0xFF2563EB), size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Lihat Bukti Transfer",
                              style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Color(0xFF2563EB), size: 20),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _rejectRequest(doc.id),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.close, size: 18),
                              SizedBox(width: 8),
                              Text("Tolak", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF10B981),
                            side: const BorderSide(color: Color(0xFF10B981)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () => _approveRequest(doc.id, storeId, tokens, validDays),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check, size: 18),
                              SizedBox(width: 8),
                              Text("Setujui", style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }, // closes FutureBuilder builder
        ); // closes return FutureBuilder
      }, // closes itemBuilder
    ); // closes return ListView.builder
  }, // closes StreamBuilder builder
); // closes return StreamBuilder
}

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                if (label == "Store ID")
                  const Icon(Icons.copy, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddTokenPackageForm extends StatefulWidget {
  const AddTokenPackageForm({super.key});

  @override
  State<AddTokenPackageForm> createState() => _AddTokenPackageFormState();
}

class _AddTokenPackageFormState extends State<AddTokenPackageForm> {
  final _formKey = GlobalKey<FormState>();
  String _name = "";
  int _tokens = 0;
  int _price = 0;
  int _validDays = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final fillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Buat Paket Token", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Nama Paket",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "Contoh: Paket Super 200",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.isEmpty ? "Wajib diisi" : null,
                onSaved: (val) => _name = val!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Jumlah Token",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "Contoh: 200",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || int.tryParse(val) == null ? "Masukkan angka valid" : null,
                onSaved: (val) => _tokens = int.parse(val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Harga (Rp)",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "Contoh: 100000",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || int.tryParse(val) == null ? "Masukkan angka valid" : null,
                onSaved: (val) => _price = int.parse(val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Masa Berlaku (Hari)",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: "Contoh: 30 (Ketik 0 untuk Lifetime)",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: fillColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || int.tryParse(val) == null ? "Masukkan angka valid" : null,
                onSaved: (val) => _validDays = int.parse(val!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      Navigator.pop(context, {
                        "name": _name,
                        "tokens": _tokens,
                        "price": _price,
                        "valid_days": _validDays,
                      });
                    }
                  },
                  child: const Text("Simpan Paket", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class ManualTransferDialog extends StatefulWidget {
  final Map<String, dynamic> package;
  final String storeId;
  final VoidCallback onSuccess;

  const ManualTransferDialog({super.key, required this.package, required this.storeId, required this.onSuccess});

  @override
  State<ManualTransferDialog> createState() => _ManualTransferDialogState();
}

class _ManualTransferDialogState extends State<ManualTransferDialog> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedFile;
  Uint8List? _fileBytes;
  bool _isLoading = false;

  final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedFile = image;
          _fileBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint("Gagal memilih gambar: $e");
    }
  }

  Future<void> _submitTransfer() async {
    if (_selectedFile == null || _fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih foto bukti transfer terlebih dahulu.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sesuaikan IP Node.js Anda
      const String serverUrl = 'http://103.150.226.111:3000';

      // 1. Upload File
      var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload-proof'));
      request.files.add(http.MultipartFile.fromBytes(
        'proof',
        _fileBytes!,
        filename: _selectedFile!.name,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        String fileUrl = json['url'];

        // 2. Simpan ke Firebase
        await FirebaseFirestore.instance.collection('token_requests').add({
          'store_id': widget.storeId,
          'package_name': widget.package['name'],
          'tokens': widget.package['tokens'],
          'valid_days': widget.package['valid_days'] ?? 0,
          'price': widget.package['price'],
          'method': 'Transfer Manual',
          'status': 'Pending',
          'proof_url': '$serverUrl$fileUrl',
          'created_at': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess();
        }
      } else {
        throw 'Gagal upload bukti (Status ${response.statusCode})';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)]),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.account_balance, color: Colors.white, size: 48),
                    SizedBox(height: 8),
                    Text("Transfer Manual", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Jumlah Tagihan:", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    Text(currencyFormatter.format(widget.package['price']), style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF10B981))),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Transfer Ke Rekening Berikut:", style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text("DANA", style: TextStyle(fontSize: 16, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          Text("085882144478", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          Text("a.n CECEP SUDRAJAT", style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text("Upload Bukti Pembayaran:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickImage,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3), style: BorderStyle.solid),
                        ),
                        child: _fileBytes != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_fileBytes!, fit: BoxFit.cover, width: double.infinity))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text("Pilih Foto Bukti", style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _isLoading ? null : _submitTransfer,
                        child: _isLoading 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("Konfirmasi Pembayaran", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;

  _SliverTabBarDelegate(this._tabBar, {required this.color});

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

class PaymentDetailsPage extends StatefulWidget {
  final Map<String, dynamic> package;
  final String storeId;
  final Function(Map<String, dynamic>, String) onProcessBuyToken;
  final Function(Map<String, dynamic>) onShowManualTransfer;

  const PaymentDetailsPage({
    super.key,
    required this.package,
    required this.storeId,
    required this.onProcessBuyToken,
    required this.onShowManualTransfer,
  });

  @override
  State<PaymentDetailsPage> createState() => _PaymentDetailsPageState();
}

class _PaymentDetailsPageState extends State<PaymentDetailsPage> {
  final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  String _selectedMethod = 'transfer'; // transfer, ewallet, qris

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text("Detail Pembayaran", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Package Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.local_laundry_service, color: Color(0xFF6366F1), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.package['name'], style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text("${widget.package['tokens']} Token", style: const TextStyle(color: Color(0xFF6366F1), fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Masa Berlaku", style: TextStyle(color: subTextColor, fontSize: 14)),
                            Text(widget.package['valid_days'] > 0 ? '${widget.package['valid_days']} Hari' : 'Lifetime', style: TextStyle(color: textColor, fontSize: 14)),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Harga", style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(currencyFormatter.format(widget.package['price']), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  Text("Metode Pembayaran", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Payment Methods
                  _buildMethodOption('transfer', Icons.account_balance, "Transfer Bank", "Transfer manual ke rekening", isDark, cardColor, textColor, subTextColor),
                  _buildMethodOption('ewallet', Icons.account_balance_wallet, "E-Wallet", "OVO, DANA, GoPay, ShopeePay", isDark, cardColor, textColor, subTextColor),
                  _buildMethodOption('qris', Icons.qr_code_scanner, "QRIS", "Scan QR untuk pembayaran", isDark, cardColor, textColor, subTextColor),
                  
                  const SizedBox(height: 32),
                  // Ringkasan Pembayaran
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ringkasan Pembayaran", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Paket", style: TextStyle(color: subTextColor, fontSize: 14)),
                            Text("${widget.package['name']} (${widget.package['tokens']} Token)", style: TextStyle(color: subTextColor, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Harga", style: TextStyle(color: subTextColor, fontSize: 14)),
                            Text(currencyFormatter.format(widget.package['price']), style: TextStyle(color: subTextColor, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Biaya Admin", style: TextStyle(color: subTextColor, fontSize: 14)),
                            Text("Rp 0", style: TextStyle(color: subTextColor, fontSize: 14)),
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Total Pembayaran", style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(currencyFormatter.format(widget.package['price']), style: const TextStyle(color: Color(0xFF6366F1), fontSize: 20, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Bottom Nav Konfirmasi
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_selectedMethod == 'transfer') {
                    widget.onShowManualTransfer(widget.package);
                  } else {
                    widget.onProcessBuyToken(widget.package, 'Midtrans');
                  }
                },
                icon: const Icon(Icons.verified_user_outlined, color: Colors.white),
                label: const Text("Konfirmasi & Bayar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodOption(String value, IconData icon, String title, String subtitle, bool isDark, Color cardColor, Color textColor, Color subTextColor) {
    final isSelected = _selectedMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _selectedMethod,
              onChanged: (val) {
                setState(() => _selectedMethod = val!);
              },
              activeColor: const Color(0xFF2563EB),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
