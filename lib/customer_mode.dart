import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:aplikasilaundry/activity_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CustomerModePage extends StatefulWidget {
  final String storeId;

  const CustomerModePage({Key? key, required this.storeId}) : super(key: key);

  @override
  _CustomerModePageState createState() => _CustomerModePageState();
}

class _CustomerModePageState extends State<CustomerModePage> {
  // Simpan timer yang sedang berjalan untuk animasi mundur
  Map<String, Timer> _machineTimers = {};
  Map<String, int> _remainingSeconds = {};

  @override
  void dispose() {
    for (var timer in _machineTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  void _updateTimers(List<QueryDocumentSnapshot> docs) {
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final machineId = doc.id;
      final status = data['status'];
      final timerEnabled = data['timer_enabled'] ?? false;
      
      if (status == 'Active' && timerEnabled && data['start_time'] != null && data['duration_minutes'] != null) {
        final startTime = (data['start_time'] as Timestamp).toDate();
        final durationMinutes = data['duration_minutes'] as int;
        final endTime = startTime.add(Duration(minutes: durationMinutes));
        final remaining = endTime.difference(DateTime.now()).inSeconds;

        if (remaining > 0) {
          if (!_machineTimers.containsKey(machineId)) {
            _remainingSeconds[machineId] = remaining;
            _machineTimers[machineId] = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (!mounted) {
                timer.cancel();
                return;
              }
              setState(() {
                if (_remainingSeconds[machineId]! > 0) {
                  _remainingSeconds[machineId] = _remainingSeconds[machineId]! - 1;
                } else {
                  timer.cancel();
                  _machineTimers.remove(machineId);
                }
              });
            });
          }
        } else {
          _remainingSeconds[machineId] = 0;
          _machineTimers[machineId]?.cancel();
          _machineTimers.remove(machineId);
        }
      } else {
        _machineTimers[machineId]?.cancel();
        _machineTimers.remove(machineId);
        _remainingSeconds.remove(machineId);
      }
    }
  }

  Future<void> _payServiceQRIS(String customerName, String customerPhone, int washQty, int dryQty, int price) async {
    // 1. Cek ketersediaan token toko
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .doc(widget.storeId)
        .collection('token_batches')
        .where('remaining_tokens', isGreaterThan: 0)
        .get();

    String? selectedBatchId;
    int neededTokens = washQty + dryQty;
    for (var doc in snap.docs) {
      final data = doc.data();
      bool isExpired = false;
      if (data.containsKey('expired_at') && data['expired_at'] != null) {
        final exp = (data['expired_at'] as Timestamp).toDate();
        if (DateTime.now().isAfter(exp)) isExpired = true;
      }
      if (!isExpired && data['remaining_tokens'] >= neededTokens) {
        selectedBatchId = doc.id;
        break; // Ambil token aktif pertama yang mencukupi
      }
    }

    if (selectedBatchId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maaf, layanan sedang tidak tersedia (Token toko habis). Silakan lapor kasir.")));
      return;
    }

    // 2. Tampilkan loading
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    // 3. Panggil API Midtrans
    try {
      const String serverUrl = 'http://103.150.226.111:3000/pay-service';
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'price': price,
          'store_id': widget.storeId,
          'customer_name': customerName,
          'customer_phone': customerPhone,
          'service_type': 'Custom',
          'wash_quantity': washQty,
          'dry_quantity': dryQty,
          'batch_id': selectedBatchId,
        }),
      );

      if (mounted) Navigator.pop(context); // Tutup loading

      if (response.statusCode == 200) {
        await ActivityService.logActivity(
          storeId: widget.storeId,
          action: "Pelanggan $customerName memproses pesanan layanan Cuci x$washQty Kering x$dryQty via QRIS",
        );

        final responseData = jsonDecode(response.body);
        final redirectUrl = responseData['redirect_url'];
        final orderId = responseData['order_id'];
        
        if (redirectUrl != null) {
          final uri = Uri.parse(redirectUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }

        // Tampilkan dialog menunggu pembayaran & struk
        if (orderId != null) {
          _waitForPaymentAndShowReceipt(orderId, customerName, washQty, dryQty, price);
        }

      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mendapatkan QRIS: ${response.body}")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghubungi server: $e")));
    }
  }

  void _waitForPaymentAndShowReceipt(String orderId, String customerName, int washQty, int dryQty, int price) {
    // Tampilkan dialog loading
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
              const Text("Silakan selesaikan pembayaran di Midtrans. Struk akan muncul otomatis setelah berhasil.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Batal menunggu
                },
                child: const Text("Tutup Jendela Ini"),
              )
            ],
          ),
        );
      }
    );

    // Listen ke Firestore
    StreamSubscription<DocumentSnapshot>? sub;
    sub = FirebaseFirestore.instance.collection('service_requests').doc(orderId).snapshots().listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['status'] == 'Paid') {
          // Tutup loading
          sub?.cancel();
          if (mounted) {
            Navigator.pop(context); // Tutup dialog menunggu
            _showReceiptDialog(orderId, customerName, washQty, dryQty, price);
          }
        }
      }
    });
  }

  void _showReceiptDialog(String orderId, String customerName, int washQty, int dryQty, int price) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 300,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 8),
                const Text("Pembayaran Berhasil!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                const Divider(),
                Text("Pesanan: $orderId", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Pelanggan:"),
                    Text(customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                if (washQty > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Cuci (Washer):"),
                      Text("x$washQty"),
                    ],
                  ),
                if (dryQty > 0)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Kering (Dryer):"),
                      Text("x$dryQty"),
                    ],
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total Bayar:", style: TextStyle(fontWeight: FontWeight.bold)),
                    Text("Rp ${NumberFormat('#,###', 'id_ID').format(price)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _printReceipt(orderId, customerName, washQty, dryQty, price);
                  },
                  icon: const Icon(Icons.print, color: Colors.white),
                  label: const Text("Print Struk (58mm)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup", style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Future<void> _printReceipt(String orderId, String customerName, int washQty, int dryQty, int price) async {
    final pdf = pw.Document();
    
    // Set ukuran kertas ke 58mm (Roll57)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll57,
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text("SMART LAUNDRY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: const pw.TextStyle(fontSize: 8)),
                pw.Text("ID: $orderId", style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("Pelanggan:", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(customerName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.SizedBox(height: 4),
                if (washQty > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Cuci", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("x$washQty", style: const pw.TextStyle(fontSize: 10)),
                    ]
                  ),
                if (dryQty > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Kering", style: const pw.TextStyle(fontSize: 10)),
                      pw.Text("x$dryQty", style: const pw.TextStyle(fontSize: 10)),
                    ]
                  ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL:", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Rp ${NumberFormat('#,###', 'id_ID').format(price)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ]
                ),
                pw.SizedBox(height: 12),
                pw.Text("Terima Kasih", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.Text("Harap simpan struk ini", style: const pw.TextStyle(fontSize: 8)),
              ]
            )
          );
        }
      )
    );

    // Langsung print melalui dialog browser (Print package otomatis menangani flutter web)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Struk-$orderId',
      format: PdfPageFormat.roll57, // Paksa layout ke roll57
    );
  }

  void _showOrderDialog(int defaultWashPrice, int defaultDryPrice) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final snap = await FirebaseFirestore.instance
        .collection('pelanggan')
        .where('store_id', isEqualTo: widget.storeId)
        .get();
        
    if (mounted) Navigator.pop(context); // Tutup loading

    List<Map<String, dynamic>> customers = snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        final nameController = TextEditingController();
        final phoneController = TextEditingController();
        String selectedRealPhone = '';
        int washQty = 1; // Default
        int dryQty = 0; // Default
        
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            int currentPrice = (defaultWashPrice * washQty) + (defaultDryPrice * dryQty);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text("Pesan Layanan", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Masukkan data diri Anda atau cari nama jika sudah pernah mencuci di sini.", style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 16),
                      Autocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Map<String, dynamic>>.empty();
                          }
                          return customers.where((c) {
                            final name = c['name']?.toString().toLowerCase() ?? '';
                            return name.contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        displayStringForOption: (option) => option['name'] ?? '',
                        onSelected: (option) {
                          nameController.text = option['name'] ?? '';
                          String rawPhone = option['phone'] ?? '';
                          selectedRealPhone = rawPhone;
                          if (rawPhone.length > 4) {
                            phoneController.text = 'xxxx' + rawPhone.substring(rawPhone.length - 4);
                          } else {
                            phoneController.text = rawPhone;
                          }
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          controller.addListener(() {
                            if (nameController.text != controller.text) {
                              nameController.text = controller.text;
                            }
                          });
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: "Nama",
                              prefixIcon: const Icon(Icons.person),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => v == null || v.isEmpty ? "Nama wajib diisi" : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: "Nomor WhatsApp",
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? "Nomor wajib diisi" : null,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, left: 4.0, right: 4.0),
                        child: Text(
                          "💡 Masukkan WA Anda untuk mendapatkan info diskon & promo event menarik dari kami!",
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            // Row Wash
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Cuci (Washer)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("Rp ${NumberFormat('#,###', 'id_ID').format(defaultWashPrice)}", style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: washQty > 0 ? Colors.blue : Colors.grey),
                                      onPressed: washQty > 0 ? () => setStateBuilder(() => washQty--) : null,
                                    ),
                                    Text("$washQty", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                      onPressed: () => setStateBuilder(() => washQty++),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const Divider(height: 24),
                            // Row Dry
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Kering (Dryer)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("Rp ${NumberFormat('#,###', 'id_ID').format(defaultDryPrice)}", style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.remove_circle_outline, color: dryQty > 0 ? Colors.blue : Colors.grey),
                                      onPressed: dryQty > 0 ? () => setStateBuilder(() => dryQty--) : null,
                                    ),
                                    Text("$dryQty", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                      onPressed: () => setStateBuilder(() => dryQty++),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Bayar:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Rp ${NumberFormat('#,###', 'id_ID').format(currentPrice)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      String phone = phoneController.text.trim();
                      
                      if (selectedRealPhone.isNotEmpty && phone.length > 4 && phone == ('xxxx' + selectedRealPhone.substring(selectedRealPhone.length - 4))) {
                        phone = selectedRealPhone;
                      }
                      
                      // Cek apakah pelanggan ini baru
                      final existing = customers.where((c) => c['name'] == name && c['phone'] == phone).toList();
                      if (existing.isEmpty) {
                        // Simpan ke Firestore
                        await FirebaseFirestore.instance.collection('pelanggan').add({
                          'name': name,
                          'phone': phone,
                          'store_id': widget.storeId,
                        });
                      }

                      if (washQty == 0 && dryQty == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 layanan Cuci atau Kering")));
                        return;
                      }

                      if (mounted) {
                        Navigator.pop(context); // Tutup form dialog
                        _payServiceQRIS(name, phone, washQty, dryQty, currentPrice);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981), // Hijau Midtrans
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Bayar Pakai QRIS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _confirmPlay(Map<String, dynamic> machine, String machineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Konfirmasi Mulai"),
        content: Text("Apakah Anda (${machine['assigned_to']}) sudah memasukkan pakaian dan menutup pintu mesin ${machine['name']}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Belum", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Ubah status jadi Active, trigger server & esp32
              await FirebaseFirestore.instance.collection('machines').doc(machineId).update({
                'status': 'Active',
                'start_time': FieldValue.serverTimestamp(),
              });
              
              await ActivityService.logActivity(
                storeId: widget.storeId,
                action: "Pelanggan ${machine['assigned_to']} memulai mesin ${machine['name']}",
              );
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mesin ${machine['name']} dimulai!")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text("Ya, Mulai Mesin!", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('machines')
                .where('store_id', isEqualTo: widget.storeId)
                .snapshots(),
            builder: (context, machineSnapshot) {
              if (machineSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final machines = machineSnapshot.data?.docs ?? [];
              // Pisahkan Washer dan Dryer
              final washers = machines.where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'Washer').toList();
              final dryers = machines.where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'Dryer').toList();
              
              // Sort by name
              washers.sort((a, b) => ((a.data() as Map<String, dynamic>)['name'] ?? '').compareTo((b.data() as Map<String, dynamic>)['name'] ?? ''));
              dryers.sort((a, b) => ((a.data() as Map<String, dynamic>)['name'] ?? '').compareTo((b.data() as Map<String, dynamic>)['name'] ?? ''));

              final allSortedMachines = [...washers, ...dryers];

              // Hitung default price
              int defaultWashPrice = 15000;
              int defaultDryPrice = 15000;
              if (washers.isNotEmpty) {
                defaultWashPrice = (washers.first.data() as Map<String, dynamic>)['price'] ?? 15000;
              }
              if (dryers.isNotEmpty) {
                defaultDryPrice = (dryers.first.data() as Map<String, dynamic>)['price'] ?? 15000;
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _updateTimers(machines);
              });

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('queues')
                    .where('store_id', isEqualTo: widget.storeId)
                    .where('status', isEqualTo: 'Pending')
                    .orderBy('created_at', descending: false)
                    .snapshots(),
                builder: (context, queueSnapshot) {
                  List<QueryDocumentSnapshot> pendingQueues = [];
                  if (queueSnapshot.hasData) {
                    pendingQueues = queueSnapshot.data!.docs;
                  }

                  return Column(
                    children: [
                      // Header & Tombol Utama
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Self-Service Laundry", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis),
                                        Text("Pesan layanan & pantau mesin", style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showOrderDialog(defaultWashPrice, defaultDryPrice),
                              icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                              label: const Text("PESAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool isWide = constraints.maxWidth >= 900;
                            
                            Widget gridSection = Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Status Mesin", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: allSortedMachines.isEmpty 
                                      ? const Center(child: Text("Belum ada mesin.", style: TextStyle(fontSize: 16, color: Color(0xFF64748B))))
                                      : GridView.builder(
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: isWide ? 2 : (constraints.maxWidth > 600 ? 2 : 1),
                                            childAspectRatio: isWide ? 1.2 : 1.5,
                                            crossAxisSpacing: 16,
                                            mainAxisSpacing: 16,
                                          ),
                                          itemCount: allSortedMachines.length,
                                          itemBuilder: (context, index) {
                                          final machineData = allSortedMachines[index].data() as Map<String, dynamic>;
                                          final machineId = allSortedMachines[index].id;
                                          final status = machineData['status'] ?? 'Idle';
                                          final isWasher = machineData['type'] == 'Washer';

                                          Color cardColor;
                                          Color textColor;
                                          if (status == 'Active') {
                                            cardColor = const Color(0xFFFEE2E2);
                                            textColor = const Color(0xFFDC2626);
                                          } else if (status == 'Ready') {
                                            cardColor = const Color(0xFFFEF3C7);
                                            textColor = const Color(0xFFD97706);
                                          } else {
                                            cardColor = Colors.white;
                                            textColor = const Color(0xFF10B981);
                                          }

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: cardColor, width: 2),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                                              ],
                                            ),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                                                  child: Text(
                                                    status == 'Active' ? 'Sedang Dipakai' : (status == 'Ready' ? 'Siap Digunakan' : 'Tersedia'),
                                                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Icon(
                                                  isWasher ? Icons.local_laundry_service : Icons.dry_cleaning,
                                                  size: 54,
                                                  color: const Color(0xFF2563EB),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(machineData['name'] ?? 'Mesin', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                                const SizedBox(height: 8),

                                                if (status == 'Active') ...[
                                                  Text(
                                                    "${((_remainingSeconds[machineId] ?? 0) ~/ 60).toString().padLeft(2, '0')}:${((_remainingSeconds[machineId] ?? 0) % 60).toString().padLeft(2, '0')}",
                                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                                  ),
                                                ] else if (status == 'Ready') ...[
                                                  Text("Milik: ${machineData['assigned_to']}", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                                                  const SizedBox(height: 8),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _confirmPlay(machineData, machineId),
                                                    icon: const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                                                    label: const Text("PLAY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFF2563EB),
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    ),
                                                  )
                                                ] else ...[
                                                  Text("Mesin Cuci", style: TextStyle(color: Colors.grey[600])),
                                                ]
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );

                            Widget queueSection = Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: isWide 
                                    ? const Border(left: BorderSide(color: Color(0xFFE5E7EB)))
                                    : const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.people_alt, color: Color(0xFF2563EB)),
                                        SizedBox(width: 8),
                                        Text("Daftar Antrean", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(
                                      child: pendingQueues.isEmpty
                                          ? const Center(child: Text("Tidak ada antrean saat ini.", style: TextStyle(color: Colors.grey)))
                                          : ListView.builder(
                                              itemCount: pendingQueues.length,
                                              itemBuilder: (context, index) {
                                                final q = pendingQueues[index].data() as Map<String, dynamic>;
                                                return Card(
                                                  elevation: 0,
                                                  color: const Color(0xFFF8FAFC),
                                                  margin: const EdgeInsets.only(bottom: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    side: BorderSide(color: Colors.blue.shade100),
                                                  ),
                                                  child: ListTile(
                                                    leading: CircleAvatar(
                                                      backgroundColor: Colors.blue.shade100,
                                                      child: Text("${index + 1}", style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                                    ),
                                                    title: Text(q['customer_name'] ?? 'Pelanggan', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                    subtitle: Text("Menunggu: ${q['step'] == 'Wash' ? 'Washer' : 'Dryer'}"),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                    
                                    // Tombol Keluar (Admin/Kasir)
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              final pinController = TextEditingController();
                                              return AlertDialog(
                                                title: const Text("Keluar dari Mode Pelanggan"),
                                                content: TextField(
                                                  controller: pinController,
                                                  obscureText: true,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(labelText: "Masukkan PIN Admin", border: OutlineInputBorder()),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      if (pinController.text == "1234") {
                                                        Navigator.pop(context);
                                                        Navigator.pop(context);
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PIN Salah!")));
                                                      }
                                                    },
                                                    child: const Text("Keluar"),
                                                  )
                                                ],
                                              );
                                            }
                                          );
                                        },
                                        icon: const Icon(Icons.lock, color: Colors.grey),
                                        label: const Text("Keluar (Admin)", style: TextStyle(color: Colors.grey), overflow: TextOverflow.ellipsis),
                                      ),
                                    )
                                  ],
                                ),
                              );

                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 3, child: gridSection),
                                  Expanded(flex: 1, child: queueSection),
                                ],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: gridSection),
                                  Expanded(flex: 1, child: queueSection),
                                ],
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  );
                }
              );
            },
          ),
        ),
      ),
    );
  }
}
