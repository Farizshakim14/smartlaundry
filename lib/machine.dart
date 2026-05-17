import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/activity_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class MachinePage extends StatefulWidget {
  final String? selectedStoreId;
  const MachinePage({super.key, this.selectedStoreId});

  @override
  State<MachinePage> createState() => _MachinePageState();
}

class _MachinePageState extends State<MachinePage> {

  void _showPlayMachineDialog(String machineId, Map<String, dynamic> machine) {
    if (widget.selectedStoreId == null) return;
    bool enableTimer = false;
    int duration = 0;
    String paymentMethod = "Cashier";
    String? selectedBatchId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text("Start ${machine['name']}", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Aktifkan Timer?", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        Switch(
                          value: enableTimer,
                          onChanged: (val) {
                            setDialogState(() {
                              enableTimer = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (enableTimer) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: "Durasi (Menit)",
                          labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        onChanged: (val) {
                          duration = int.tryParse(val) ?? 0;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text("Metode Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    RadioListTile<String>(
                      title: Text("Kasir", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      value: "Cashier",
                      groupValue: paymentMethod,
                      onChanged: (val) {
                        setDialogState(() {
                          paymentMethod = val!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: Text("QRIS", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                      value: "QRIS",
                      groupValue: paymentMethod,
                      onChanged: (val) {
                        setDialogState(() {
                          paymentMethod = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    Text("Pilih Paket Token", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('stores')
                          .doc(widget.selectedStoreId)
                          .collection('token_batches')
                          .where('remaining_tokens', isGreaterThan: 0)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text("Tidak ada token tersedia", style: TextStyle(color: Colors.red));
                        }
                        
                        List<Map<String, dynamic>> activeBatches = [];
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          bool isExpired = false;
                          if (data['expired_at'] != null) {
                            final exp = (data['expired_at'] as Timestamp).toDate();
                            if (DateTime.now().isAfter(exp)) isExpired = true;
                          }
                          if (!isExpired) {
                            data['id'] = doc.id;
                            activeBatches.add(data);
                          }
                        }

                        if (activeBatches.isEmpty) {
                          return const Text("Semua token telah kadaluarsa", style: TextStyle(color: Colors.red));
                        }

                        if (selectedBatchId == null && activeBatches.isNotEmpty) {
                          selectedBatchId = activeBatches.first['id'];
                        }

                        return Column(
                          children: activeBatches.map((batch) {
                            final name = batch['package_name'] ?? 'Paket Token';
                            final rem = batch['remaining_tokens'];
                            
                            return StreamBuilder(
                              stream: Stream.periodic(const Duration(seconds: 1)),
                              builder: (context, _) {
                                String expStr = "Lifetime";
                                if (batch['expired_at'] != null) {
                                  final expDate = (batch['expired_at'] as Timestamp).toDate();
                                  final diff = expDate.difference(DateTime.now());
                                  if (diff.inDays > 0) {
                                    expStr = "Sisa ${diff.inDays} Hari (Hingga ${expDate.day}/${expDate.month}/${expDate.year})";
                                  } else {
                                    final hours = diff.inHours.toString().padLeft(2, '0');
                                    final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
                                    final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
                                    expStr = "Sisa $hours:$minutes:$seconds (Hingga Pukul ${expDate.hour.toString().padLeft(2, '0')}:${expDate.minute.toString().padLeft(2, '0')})";
                                  }
                                }

                                return RadioListTile<String>(
                                  title: Text("$name ($rem Token)", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                  subtitle: Text(expStr, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                                  value: batch['id'],
                                  groupValue: selectedBatchId,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      selectedBatchId = val;
                                    });
                                  },
                                );
                              }
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  onPressed: () async {
                    if (enableTimer && duration <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Durasi harus lebih dari 0 menit')));
                      return;
                    }
                    if (selectedBatchId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih token terlebih dahulu')));
                      return;
                    }
                    if (paymentMethod == "QRIS") {
                      if (machine['price'] == null || machine['price'] == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harga mesin belum disetel! Silakan edit mesin.')));
                        return;
                      }
                      Navigator.pop(context);
                      await _payMachineMidtrans(machineId, machine, enableTimer, duration, selectedBatchId!, machine['price']);
                    } else {
                      Navigator.pop(context);
                      await _startMachine(machineId, machine, enableTimer, duration, paymentMethod, selectedBatchId!);
                    }
                  },
                  child: const Text("Play", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _startMachine(String machineId, Map<String, dynamic> machine, bool enableTimer, int duration, String paymentMethod, String batchId) async {
    if (widget.selectedStoreId == null) return;

    // 1. Cek dan Potong Saldo Token dari Batch
    final batchRef = FirebaseFirestore.instance.collection('stores').doc(widget.selectedStoreId).collection('token_batches').doc(batchId);
    final batchDoc = await batchRef.get();
    
    if (!batchDoc.exists) return;
    
    final remainingTokens = batchDoc.data()!['remaining_tokens'] as int;

    if (remainingTokens < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Token tidak cukup! Silakan beli token terlebih dahulu."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return; // Batalkan proses start
    }
    
    final newBalance = remainingTokens - 1;
    await batchRef.update({'remaining_tokens': newBalance});

    final now = FieldValue.serverTimestamp();
    
    // Update status mesin
    await FirebaseFirestore.instance.collection('machines').doc(machineId).update({
      'status': 'Active',
      'timer_enabled': enableTimer,
      'duration_minutes': enableTimer ? duration : 0,
      'start_time': now,
      'payment_method': paymentMethod,
    });

    // Catat ke log aktivitas
    await ActivityService.logActivity(
      storeId: widget.selectedStoreId,
      action: "Memulai mesin ${machine['name']} (${enableTimer ? '$duration Menit' : 'Tanpa Timer'}) dengan pembayaran $paymentMethod",
    );

    // Catat ke tabel transaksi
    await FirebaseFirestore.instance.collection('transactions').add({
      'store_id': widget.selectedStoreId,
      'machine_id': machineId,
      'machine_name': machine['name'],
      'machine_type': machine['type'],
      'timer_enabled': enableTimer,
      'duration_minutes': enableTimer ? duration : 0,
      'payment_method': paymentMethod,
      'amount': machine['price'] ?? 0,
      'timestamp': now,
      'status': 'Completed', 
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${machine['name']} dimulai! Saldo terpotong 1 Token.")));

      if (newBalance <= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Peringatan: Token Anda sisa $newBalance. Segera beli token baru!"),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _payMachineMidtrans(String machineId, Map<String, dynamic> machine, bool enableTimer, int duration, String batchId, int price) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      const String serverUrl = 'http://103.150.226.111:3000/pay-machine';
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'price': price,
          'store_id': widget.selectedStoreId,
          'machine_id': machineId,
          'machine_name': machine['name'],
          'machine_type': machine['type'],
          'timer_enabled': enableTimer,
          'duration_minutes': duration,
          'batch_id': batchId,
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
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menunggu pembayaran. Mesin akan otomatis menyala setelah dibayar.")));
            }
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error Midtrans: ${response.body}")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghubungi server: $e")));
    }
  }

  Future<void> _stopMachine(String machineId, String machineName) async {
    await FirebaseFirestore.instance.collection('machines').doc(machineId).update({
      'status': 'Idle',
      'timer_enabled': FieldValue.delete(),
      'duration_minutes': FieldValue.delete(),
      'start_time': FieldValue.delete(),
      'payment_method': FieldValue.delete(),
    });

    await ActivityService.logActivity(
      storeId: widget.selectedStoreId,
      action: "Menghentikan mesin $machineName secara manual",
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$machineName dihentikan!")));
    }
  }

  // Membuka form tambah mesin (BottomSheet)
  void _showAddMachineDialog() {
    if (widget.selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih toko terlebih dahulu.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMachineForm(selectedStoreId: widget.selectedStoreId!),
    ).then((newMachine) async {
      // Jika form dikembalikan (submit) dengan data baru, tambahkan ke Firestore
      if (newMachine != null) {
        await FirebaseFirestore.instance.collection('machines').add(newMachine);
        
        await ActivityService.logActivity(
          storeId: widget.selectedStoreId,
          action: "Menambahkan mesin baru (${newMachine['type']} - ${newMachine['name']})",
        );
        
        // Tampilkan notifikasi sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newMachine["name"]} berhasil ditambahkan!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Manage Machines",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.search, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.selectedStoreId == null
              ? const Center(child: Text("Silakan pilih toko di Dashboard terlebih dahulu.", style: TextStyle(color: Colors.grey)))
              : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: widget.selectedStoreId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_laundry_service_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "No machines added yet", 
                    style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }

          final machines = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: machines.length,
            itemBuilder: (context, index) {
              final doc = machines[index];
              final machine = doc.data() as Map<String, dynamic>;
              final isWasher = machine['type'] == 'Washer';
              
              // Memberikan default value agar tidak terjadi error jika data di Firestore belum lengkap
              final name = machine['name']?.toString() ?? 'Unknown Machine';
              final type = machine['type']?.toString() ?? 'Unknown';
              final status = machine['status']?.toString() ?? 'Idle';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    // Ikon Mesin
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isWasher ? const Color(0xFF2563EB) : const Color(0xFF10B981)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isWasher ? Icons.local_laundry_service : Icons.dry_cleaning,
                        color: isWasher ? const Color(0xFF2563EB) : const Color(0xFF10B981),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Detail Mesin
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
                            type,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: status == 'Active' ? const Color(0xFF10B981).withOpacity(0.1) : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: status == 'Active' ? const Color(0xFF10B981) : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Action Buttons
                    if (status == 'Idle')
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFF2563EB), size: 36),
                        onPressed: () => _showPlayMachineDialog(doc.id, machine),
                      )
                    else if (status == 'Active')
                      IconButton(
                        icon: const Icon(Icons.stop_circle, color: Colors.red, size: 36),
                        onPressed: () => _stopMachine(doc.id, name),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
      ),
      ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMachineDialog,
        backgroundColor: const Color(0xFF2563EB),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Machine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// Komponen Formulir Tambah Mesin
class AddMachineForm extends StatefulWidget {
  final String selectedStoreId;
  const AddMachineForm({super.key, required this.selectedStoreId});

  @override
  State<AddMachineForm> createState() => _AddMachineFormState();
}

class _AddMachineFormState extends State<AddMachineForm> {
  final _formKey = GlobalKey<FormState>();
  String? _machineName;
  String _machineType = "Washer"; // Nilai default
  int? _machinePrice;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      // Padding agar form tidak tertutup keyboard
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Sesuaikan tinggi dengan konten
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Add New Machine",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pilihan Tipe Mesin
              Text(
                "Machine Type",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeSelector("Washer", Icons.local_laundry_service, isDark),
                  const SizedBox(width: 16),
                  _buildTypeSelector("Dryer", Icons.dry_cleaning, isDark),
                ],
              ),
              const SizedBox(height: 24),

              // Input Nama Mesin
              Text(
                "Machine Name / ID",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _machineName,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                decoration: InputDecoration(
                  hintText: "Select Machine",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: (_machineType == 'Washer'
                        ? ['Washer 1', 'Washer 2', 'Washer 3', 'Washer 4']
                        : ['Dryer 1', 'Dryer 2', 'Dryer 3', 'Dryer 4'])
                    .map((name) => DropdownMenuItem(
                          value: name,
                          child: Text(name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _machineName = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please select a machine";
                  }
                  return null;
                },
                onSaved: (value) {
                  _machineName = value;
                },
              ),
              const SizedBox(height: 24),

              // Input Harga
              Text(
                "Harga per Pemakaian (Rp)",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Contoh: 15000",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Masukkan harga mesin";
                  }
                  if (int.tryParse(value) == null) {
                    return "Masukkan angka yang valid";
                  }
                  return null;
                },
                onSaved: (value) {
                  _machinePrice = int.parse(value!);
                },
              ),
              const SizedBox(height: 32),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0072FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF0072FF).withOpacity(0.4),
                  ),
                  onPressed: () {
                    // Validasi form
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      // Kembalikan data mesin baru ke halaman sebelumnya
                      Navigator.pop(context, {
                        "name": _machineName,
                        "type": _machineType,
                        "status": "Idle", // Status bawaan
                        "store_id": widget.selectedStoreId,
                        "price": _machinePrice,
                      });
                    }
                  },
                  child: const Text(
                    "Save Machine",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Widget custom untuk memilih tipe (Washer/Dryer)
  Widget _buildTypeSelector(String type, IconData icon, bool isDark) {
    final isSelected = _machineType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _machineType = type;
            _machineName = null; // Reset selection when type changes
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0072FF).withOpacity(0.1) : (isDark ? const Color(0xFF1E293B) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF0072FF) : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF0072FF) : Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                type,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF0072FF) : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
