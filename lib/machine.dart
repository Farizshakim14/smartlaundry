import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/activity_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class MachinePage extends StatefulWidget {
  final String? selectedStoreId;
  final String userRole;
  const MachinePage({super.key, this.selectedStoreId, required this.userRole});

  @override
  State<MachinePage> createState() => _MachinePageState();
}

class _MachinePageState extends State<MachinePage> {
  String _searchQuery = '';
  String _selectedFilter = 'Semua';

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
                         const Text("Silakan selesaikan pembayaran di Midtrans. Mesin akan otomatis menyala setelah berhasil.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
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

  // Membuka form tambah/edit mesin (BottomSheet)
  void _showAddMachineDialog({String? machineId, Map<String, dynamic>? initialData}) {
    if (widget.selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih toko terlebih dahulu.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddMachineForm(selectedStoreId: widget.selectedStoreId!, initialData: initialData),
    ).then((newMachine) async {
      // Jika form dikembalikan (submit) dengan data baru, tambahkan/update ke Firestore
      if (newMachine != null) {
        if (machineId == null) {
          await FirebaseFirestore.instance.collection('machines').add(newMachine);
          await ActivityService.logActivity(
            storeId: widget.selectedStoreId,
            action: "Menambahkan mesin baru (${newMachine['type']} - ${newMachine['name']})",
          );
        } else {
          await FirebaseFirestore.instance.collection('machines').doc(machineId).update(newMachine);
          await ActivityService.logActivity(
            storeId: widget.selectedStoreId,
            action: "Mengubah data mesin (${newMachine['type']} - ${newMachine['name']})",
          );
        }
        
        // Tampilkan notifikasi sukses
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newMachine["name"]} berhasil ${machineId == null ? "ditambahkan" : "diperbarui"}!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  void _confirmDeleteMachine(String machineId, String machineName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Mesin"),
        content: Text("Apakah Anda yakin ingin menghapus mesin '$machineName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('machines').doc(machineId).delete();
              await ActivityService.logActivity(
                storeId: widget.selectedStoreId,
                action: "Menghapus mesin ($machineName)",
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Mesin '$machineName' berhasil dihapus!")),
                );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mesin",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: widget.selectedStoreId).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          int offlineCount = 0;
                          for (var doc in snapshot.data!.docs) {
                            final m = doc.data() as Map<String, dynamic>;
                            if (m['status'] == 'Offline') offlineCount++;
                          }
                          
                          if (offlineCount == 0) {
                            return Row(
                              children: [
                                const Icon(Icons.wifi, color: Color(0xFF10B981), size: 16),
                                const SizedBox(width: 6),
                                const Text(
                                  "Semua Perangkat Online",
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Row(
                              children: [
                                const Icon(Icons.wifi_off, color: Colors.red, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "$offlineCount Perangkat Offline",
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.filter_alt_outlined, color: Color(0xFF64748B)),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: "Cari mesin...",
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF94A3B8)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Firebase Stream
            Expanded(
              child: widget.selectedStoreId == null
                  ? const Center(child: Text("Pilih toko di Dashboard terlebih dahulu."))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: widget.selectedStoreId).snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text("Tidak ada mesin."));
                        }

                        final allMachines = snapshot.data!.docs;
                        int washerCount = 0;
                        int dryerCount = 0;
                        
                        List<QueryDocumentSnapshot> filteredList = [];
                        for (var doc in allMachines) {
                          final data = doc.data() as Map<String, dynamic>;
                          final type = data['type']?.toString() ?? 'Washer';
                          final name = data['name']?.toString() ?? '';
                          
                          if (type == 'Washer') washerCount++;
                          else if (type == 'Dryer') dryerCount++;

                          if (_searchQuery.isNotEmpty && !name.toLowerCase().contains(_searchQuery)) {
                            continue;
                          }

                          if (_selectedFilter != 'Semua' && type != _selectedFilter) {
                            continue;
                          }

                          filteredList.add(doc);
                        }

                        // Filter Chips
                        return Column(
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  _buildFilterChip('Semua', 'Semua (${allMachines.length})'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Washer', 'Washer ($washerCount)'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Dryer', 'Dryer ($dryerCount)'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_selectedFilter == 'Semua' || _selectedFilter == 'Washer') ...[
                                      if (_selectedFilter == 'Semua')
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text("WASHER", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF475569), fontSize: 13, letterSpacing: 1.0)),
                                        ),
                                      _buildGrid(filteredList.where((d) => (d.data() as Map<String,dynamic>)['type'] == 'Washer').toList()),
                                      const SizedBox(height: 24),
                                    ],
                                    if (_selectedFilter == 'Semua' || _selectedFilter == 'Dryer') ...[
                                      if (_selectedFilter == 'Semua')
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text("DRYER", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF475569), fontSize: 13, letterSpacing: 1.0)),
                                        ),
                                      _buildGrid(filteredList.where((d) => (d.data() as Map<String,dynamic>)['type'] == 'Dryer').toList()),
                                      const SizedBox(height: 24),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: (widget.userRole == 'Superadmin' || widget.userRole == 'Admin') 
          ? FloatingActionButton(
              onPressed: () => _showAddMachineDialog(),
              backgroundColor: const Color(0xFF2563EB),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildFilterChip(String filterValue, String label) {
    bool isSelected = _selectedFilter == filterValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterValue;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<QueryDocumentSnapshot> docs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (docs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text("Tidak ada mesin untuk kategori ini.", style: TextStyle(color: Colors.grey))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final machine = doc.data() as Map<String, dynamic>;
        final name = machine['name']?.toString() ?? 'Machine';
        final status = machine['status']?.toString() ?? 'Idle';
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              status == 'Active' ? Icons.circle : (status == 'Idle' ? Icons.radio_button_unchecked : Icons.circle),
                              color: status == 'Active' ? const Color(0xFF10B981) : (status == 'Idle' ? const Color(0xFF10B981) : Colors.red),
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: status == 'Active' ? const Color(0xFF10B981) : (status == 'Idle' ? const Color(0xFF64748B) : Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Image and Timer info
                    Expanded(
                      child: Row(
                        children: [
                          Image.asset('assets/machine_card_icon.png', width: 45, fit: BoxFit.contain),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (status == 'Idle') ...[
                                  const Text("Siap digunakan", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                ] else if (status == 'Offline') ...[
                                  const Text("ESP32 tidak terhubung", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                ] else if (status == 'Active') ...[
                                  StreamBuilder(
                                    stream: Stream.periodic(const Duration(seconds: 1)),
                                    builder: (context, _) {
                                      String timeStr = "Active";
                                      if (machine['timer_enabled'] == true && machine['start_time'] != null && machine['duration_minutes'] != null) {
                                        final start = (machine['start_time'] as Timestamp).toDate();
                                        final duration = machine['duration_minutes'] as int;
                                        final end = start.add(Duration(minutes: duration));
                                        final diff = end.difference(DateTime.now());
                                        if (diff.isNegative) {
                                          timeStr = "00:00:00";
                                        } else {
                                          final h = diff.inHours.toString().padLeft(2, '0');
                                          final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
                                          final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
                                          timeStr = "$h:$m:$s";
                                        }
                                      } else {
                                        if (machine['start_time'] != null) {
                                          final start = (machine['start_time'] as Timestamp).toDate();
                                          final diff = DateTime.now().difference(start);
                                          final h = diff.inHours.toString().padLeft(2, '0');
                                          final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
                                          final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
                                          timeStr = "$h:$m:$s";
                                        }
                                      }
                                      double currentAmpere = 0.0;
                                      if (machine['current_ampere'] != null) {
                                        currentAmpere = (machine['current_ampere'] as num).toDouble();
                                      }
                                      final watt = currentAmpere * 220; // Asumsi 220V
                                      double kwh = 0.0;
                                      if (machine['start_time'] != null) {
                                        final start = (machine['start_time'] as Timestamp).toDate();
                                        final elapsedHours = DateTime.now().difference(start).inSeconds / 3600.0;
                                        kwh = (watt / 1000.0) * elapsedHours;
                                      }

                                      return Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            timeStr,
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text("${currentAmpere.toStringAsFixed(1)}A / ${watt.toStringAsFixed(0)}W", style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
                                          Text("${kwh.toStringAsFixed(3)} kWh", style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                        ],
                                      );
                                    }
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: status == 'Idle' 
                          ? OutlinedButton(
                              onPressed: () => _showPlayMachineDialog(doc.id, machine),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text("START", style: TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          : (status == 'Active'
                              ? ElevatedButton(
                                  onPressed: () => _stopMachine(doc.id, name),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text("STOP", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                              : OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF64748B)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text("RESTART", style: TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.bold)),
                                )
                            ),
                    ),
                  ],
                ),
              ),
              // Menu Options Overlay
              if (widget.userRole == 'Superadmin' || widget.userRole == 'Admin')
                Positioned(
                  top: 0,
                  right: -10,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddMachineDialog(machineId: doc.id, initialData: machine);
                      } else if (value == 'delete') {
                        _confirmDeleteMachine(doc.id, name);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                      const PopupMenuItem(value: 'delete', child: Text("Hapus")),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}


// Komponen Formulir Tambah Mesin
class AddMachineForm extends StatefulWidget {
  final String selectedStoreId;
  final Map<String, dynamic>? initialData;
  const AddMachineForm({super.key, required this.selectedStoreId, this.initialData});

  @override
  State<AddMachineForm> createState() => _AddMachineFormState();
}

class _AddMachineFormState extends State<AddMachineForm> {
  final _formKey = GlobalKey<FormState>();
  String? _machineName;
  String _machineType = "Washer"; // Nilai default
  int? _machinePrice;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _machineName = widget.initialData!['name'];
      _machineType = widget.initialData!['type'] ?? 'Washer';
      _machinePrice = widget.initialData!['price'];
    }
  }

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
                    widget.initialData == null ? "Add New Machine" : "Edit Machine",
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
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                borderRadius: BorderRadius.circular(16),
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
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
                initialValue: _machinePrice?.toString(),
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
                        if (widget.initialData == null) "status": "Idle", // Status bawaan jika baru
                        "store_id": widget.selectedStoreId,
                        "price": _machinePrice,
                      });
                    }
                  },
                  child: Text(
                    widget.initialData == null ? "Save Machine" : "Update Machine",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
