import 'package:flutter/material.dart';
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
                                    const Text("Midtrans (Otomatis)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                    Text("QRIS, GoPay, Transfer Bank", style: TextStyle(fontSize: 12, color: subTextColor)),
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
          final redirectUrl = responseData['redirect_url'];
          
          if (redirectUrl != null) {
            final uri = Uri.parse(redirectUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text("Menunggu Pembayaran...", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text("Silakan selesaikan pembayaran di Midtrans.\n\nSaldo token toko akan otomatis bertambah setelah pembayaran sukses dikonfirmasi.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () async {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.payment, color: Colors.white),
                            label: const Text("Buka Halaman Pembayaran", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981), // Hijau Midtrans
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Tutup Jendela Ini"),
                          )
                        ],
                      ),
                    );
                  }
                );
              }
            } else {
              throw 'Tidak dapat membuka halaman pembayaran.';
            }
          } else {
            throw 'Gagal mendapatkan link pembayaran dari server.';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text(
          "Token Management",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: textColor),
        bottom: isAdmin
            ? TabBar(
                controller: _tabController,
                labelColor: primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: primaryColor,
                tabs: const [
                  Tab(text: "Paket Token"),
                  Tab(text: "Approval Request"),
                ],
              )
            : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPackageList(),
          if (isAdmin) _buildRequestList(),
        ],
      ),
      floatingActionButton: isAdmin && _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddTokenPackageDialog,
              backgroundColor: const Color(0xFF10B981), // Emerald
              icon: const Icon(Icons.add, color: Colors.white),
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

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.monetization_on, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$tokens Token (Masa Berlaku: ${data['valid_days'] != null && data['valid_days'] > 0 ? '${data['valid_days']} Hari' : 'Lifetime'})",
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currencyFormatter.format(price),
                          style: const TextStyle(color: Color(0xFFFDE047), fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white70),
                      onPressed: () => _deletePackage(doc.id),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2563EB),
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
            final storeId = data['store_id'];
            final packageName = data['package_name'];
            final tokens = data['tokens'] as int;
            final price = data['price'] as int;
            final method = data['method'];
            final proofUrl = data['proof_url'] as String?;
            final validDays = data['valid_days'] as int? ?? 0;

            // Kita bisa ngambil nama toko kalau mau, tapi untuk simplifikasi kita tampilkan storeId.
            return Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text("$packageName ($tokens Token)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Store: $storeId\nMetode: $method\nHarga: ${currencyFormatter.format(price)}\nMasa Berlaku: ${validDays > 0 ? '$validDays Hari' : 'Lifetime'}", style: TextStyle(color: subTextColor)),
                    if (proofUrl != null) ...[
                      const SizedBox(height: 8),
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
                        child: Text("Lihat Bukti Transfer", style: TextStyle(color: const Color(0xFF2563EB), fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      ),
                    ]
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectRequest(doc.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _approveRequest(doc.id, storeId, tokens, validDays),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

