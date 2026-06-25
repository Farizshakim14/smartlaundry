import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/activity_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';

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

  Stream<QuerySnapshot>? _machinesStream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  @override
  void didUpdateWidget(MachinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStoreId != widget.selectedStoreId) {
      _initStream();
    }
  }

  void _initStream() {
    if (widget.selectedStoreId != null) {
      _machinesStream = FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: widget.selectedStoreId).snapshots();
    } else {
      _machinesStream = null;
    }
  }

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
                    Navigator.pop(context);
                    await _startMachine(machineId, machine, enableTimer, duration, "Cashier", selectedBatchId!);
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

  void _showDiagnosticsDialog(String machineId, Map<String, dynamic> machine) {
    showDialog(
      context: context,
      builder: (context) => SensorDiagnosticsDialog(
        machineId: machineId,
        machine: machine,
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
                        stream: _machinesStream,
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
                      stream: _machinesStream,
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
                            EnergyDashboard(machines: filteredList),
                            const SizedBox(height: 16),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  _buildFilterChip('Semua', 'Semua (${allMachines.length})'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Washer', 'Mesin Cuci ($washerCount)'),
                                  const SizedBox(width: 8),
                                  _buildFilterChip('Dryer', 'Mesin Pengering ($dryerCount)'),
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
                                          child: Text("MESIN CUCI", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF475569), fontSize: 13, letterSpacing: 1.0)),
                                        ),
                                      _buildGrid(filteredList.where((d) => (d.data() as Map<String,dynamic>)['type'] == 'Washer').toList()),
                                      const SizedBox(height: 24),
                                    ],
                                    if (_selectedFilter == 'Semua' || _selectedFilter == 'Dryer') ...[
                                      if (_selectedFilter == 'Semua')
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text("MESIN PENGERING", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF475569), fontSize: 13, letterSpacing: 1.0)),
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
      floatingActionButton: (widget.userRole == 'Superadmin' || widget.userRole == 'Admin' || widget.userRole == 'Owner') 
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
                              status == 'Active' ? (machine['relay_status'] == 'OFF' ? Icons.access_time : Icons.circle) : (status == 'Idle' ? Icons.radio_button_unchecked : Icons.circle),
                              color: status == 'Active' ? (machine['relay_status'] == 'OFF' ? Colors.orange : const Color(0xFF10B981)) : (status == 'Idle' ? const Color(0xFF10B981) : Colors.red),
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status == 'Active' && machine['relay_status'] == 'OFF' ? 'Menunggu ESP32...' : status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: status == 'Active' ? (machine['relay_status'] == 'OFF' ? Colors.orange : const Color(0xFF10B981)) : (status == 'Idle' ? const Color(0xFF64748B) : Colors.red),
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
                                      
                                      // Ikuti data sisa waktu langsung dari ESP32 (esp32_sct10A.ino)
                                      if (machine['type'] == 'Dryer' && machine['dryer_remaining_minutes'] != null && (machine['dryer_remaining_minutes'] as int) > 0) {
                                        timeStr = "${machine['dryer_remaining_minutes']} Menit Tersisa";
                                      } else if (machine['timer_enabled'] == true && machine['start_time'] != null && machine['duration_minutes'] != null) {
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
                                      double rawAmpere = 0.0;
                                      if (machine['current_ampere'] != null) {
                                        rawAmpere = (machine['current_ampere'] as num).toDouble();
                                      }
                                      
                                      // Gunakan arus rata-rata konstan jika sensor ESP32 membaca 0
                                      double displayAmpere = rawAmpere > 0 ? rawAmpere : (machine['type'] == 'Washer' ? 0.6 : 1.2);
                                      
                                      final watt = displayAmpere * 220; // Asumsi 220V
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
                                          Text("${displayAmpere.toStringAsFixed(1)}A / ${watt.toStringAsFixed(0)}W", style: const TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold)),
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
              if (widget.userRole == 'Superadmin' || widget.userRole == 'Admin' || widget.userRole == 'Owner')
                Positioned(
                  top: 0,
                  right: -10,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showAddMachineDialog(machineId: doc.id, initialData: machine);
                      } else if (value == 'diagnostics') {
                        _showDiagnosticsDialog(doc.id, machine);
                      } else if (value == 'delete') {
                        _confirmDeleteMachine(doc.id, name);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text("Edit")),
                      const PopupMenuItem(value: 'diagnostics', child: Text("Diagnostik & Kalibrasi")),
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
                    widget.initialData == null ? "Tambah Mesin Baru" : "Edit Mesin",
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
                "Tipe Mesin",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildTypeSelector("Washer", "Mesin Cuci", Icons.local_laundry_service, isDark),
                  const SizedBox(width: 16),
                  _buildTypeSelector("Dryer", "Mesin Pengering", Icons.dry_cleaning, isDark),
                ],
              ),
              const SizedBox(height: 24),

              // Input Nama Mesin
              Text(
                "Nama Mesin / ID",
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
                  hintText: "Pilih Mesin",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: () {
                  List<String> list = _machineType == 'Washer'
                      ? ['Mesin Cuci 1', 'Mesin Cuci 2', 'Mesin Cuci 3', 'Mesin Cuci 4', 'Washer 1', 'Washer 2', 'Washer 3', 'Washer 4']
                      : ['Mesin Pengering 1', 'Mesin Pengering 2', 'Mesin Pengering 3', 'Mesin Pengering 4', 'Dryer 1', 'Dryer 2', 'Dryer 3', 'Dryer 4'];
                  
                  if (_machineName != null && !list.contains(_machineName)) {
                    list.add(_machineName!);
                  }
                  
                  return list.map((name) => DropdownMenuItem(
                        value: name,
                        child: Text(name),
                      )).toList();
                }(),
                onChanged: (value) {
                  setState(() {
                    _machineName = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Pilih mesin terlebih dahulu";
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
                    widget.initialData == null ? "Simpan Mesin" : "Perbarui Mesin",
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
  Widget _buildTypeSelector(String type, String label, IconData icon, bool isDark) {
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
                label,
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

class SensorDiagnosticsDialog extends StatefulWidget {
  final String machineId;
  final Map<String, dynamic> machine;

  const SensorDiagnosticsDialog({super.key, required this.machineId, required this.machine});

  @override
  State<SensorDiagnosticsDialog> createState() => _SensorDiagnosticsDialogState();
}

class _SensorDiagnosticsDialogState extends State<SensorDiagnosticsDialog> {
  final TextEditingController _ampereController = TextEditingController();
  bool _isCalibrating = false;

  Future<void> _sendCalibrateCommand() async {
    final ampereStr = _ampereController.text;
    if (ampereStr.isEmpty) return;

    final ampere = double.tryParse(ampereStr.replaceAll(',', '.'));
    if (ampere == null || ampere <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Masukkan nilai ampere yang valid (> 0)")));
      return;
    }

    setState(() {
      _isCalibrating = true;
    });

    try {
      final response = await http.post(
        Uri.parse('http://103.150.226.111:3000/api/esp32/calibrate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'machine_id': widget.machineId,
          'current_ampere': ampere,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perintah kalibrasi berhasil dikirim ke antrean!"), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim perintah: ${response.body}")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() {
          _isCalibrating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('machines').doc(widget.machineId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? widget.machine;

        final rawAdc = data['raw_adc'] ?? '-';
        final zeroOffset = data['zero_offset'] ?? '-';
        final rmsV = data['rms_voltage'] ?? '-';
        final calFactor = data['calibration_factor'] ?? '-';
        final current = data['current_ampere'] ?? '-';
        final wifiSsid = data['wifi_ssid'] ?? 'Tidak diketahui';
        final wifiRssi = data['wifi_rssi'] ?? '-';

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text("Diagnostik & Kalibrasi - ${widget.machine['name']}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sensor Telemetri Real-time:", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blue[300] : Colors.blue[700])),
                const SizedBox(height: 8),
                _buildStatRow("Arus Listrik (Ampere)", "$current A", isDark),
                _buildStatRow("Raw ADC", "$rawAdc", isDark),
                _buildStatRow("Zero Offset", "$zeroOffset", isDark),
                _buildStatRow("RMS Voltage", "$rmsV V", isDark),
                _buildStatRow("Calibration Factor", "$calFactor A/V", isDark),
                const Divider(height: 16),
                Text("Jaringan WiFi ESP32:", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.teal[300] : Colors.teal[700])),
                const SizedBox(height: 8),
                _buildStatRow("Nama WiFi (SSID)", "$wifiSsid", isDark),
                _buildStatRow("Kekuatan Sinyal (RSSI)", "$wifiRssi dBm", isDark),
                const Divider(height: 32),
                Text("Kalibrasi Nirkabel (Wireless)", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.orange[300] : Colors.orange[700])),
                const SizedBox(height: 8),
                Text("Gunakan Tang Ampere untuk mengukur arus di kabel mesin, lalu masukkan angkanya di bawah ini untuk mengkalibrasi sensor ESP32.", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 16),
                TextField(
                  controller: _ampereController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Nilai Tang Ampere (A)",
                    border: const OutlineInputBorder(),
                    hintText: "Contoh: 5.4",
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
            ElevatedButton.icon(
              onPressed: _isCalibrating ? null : _sendCalibrateCommand,
              icon: _isCalibrating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync),
              label: const Text("Kalibrasi"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            )
          ],
        );
      }
    );
  }

  Widget _buildStatRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }
}

class EnergyDashboard extends StatelessWidget {
  final List<QueryDocumentSnapshot> machines;
  
  const EnergyDashboard({super.key, required this.machines});

  @override
  Widget build(BuildContext context) {
    if (machines.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sortedMachines = List<QueryDocumentSnapshot>.from(machines);
    sortedMachines.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aActive = (aData['status'] == 'Active') ? 1 : 0;
      final bActive = (bData['status'] == 'Active') ? 1 : 0;
      if (aActive != bActive) return bActive.compareTo(aActive);
      return (aData['name'] ?? '').toString().compareTo((bData['name'] ?? '').toString());
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.bolt, color: Colors.amber[600], size: 20),
              const SizedBox(width: 8),
              Text(
                "Penggunaan Energi Bulan Ini", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: isDark ? Colors.white : const Color(0xFF1E293B)
                )
              ),
            ],
          ),
        ),
        SizedBox(
          height: 175,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sortedMachines.length,
            itemBuilder: (context, index) {
              final doc = sortedMachines[index];
              final machine = doc.data() as Map<String, dynamic>;
              return _EnergyCard(machineId: doc.id, machine: machine);
            },
          ),
        ),
      ],
    );
  }
}

class _EnergyCard extends StatelessWidget {
  final String machineId;
  final Map<String, dynamic> machine;
  
  const _EnergyCard({required this.machineId, required this.machine});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = machine['name'] ?? 'Mesin';
    final type = machine['type'] ?? 'Washer';
    final status = machine['status'] ?? 'Idle';
    final currentAmpere = double.tryParse(machine['current_ampere']?.toString() ?? '0') ?? 0.0;
    
    final isActive = status == 'Active';
    final accentColor = type == 'Washer' ? Colors.blueAccent : Colors.orangeAccent;
    final glowColor = isActive ? accentColor.withOpacity(0.3) : Colors.transparent;

    final startOfMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('transactions')
          .where('machine_id', isEqualTo: machineId)
          .snapshots(),
      builder: (context, txSnapshot) {
        int historicalDurationMinutes = 0;
        if (txSnapshot.hasData) {
          for (var doc in txSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            if (timestamp != null && timestamp.isAfter(startOfMonth)) {
              historicalDurationMinutes += (data['duration_minutes'] as num?)?.toInt() ?? 0;
            }
          }
        }

        return StreamBuilder(
          stream: Stream.periodic(const Duration(seconds: 1)),
          builder: (context, _) {
            double liveDurationHours = 0.0;
            
            if (isActive && machine['start_time'] != null) {
              final startTime = (machine['start_time'] as Timestamp).toDate();
              final diff = DateTime.now().difference(startTime);
              if (!diff.isNegative) {
                liveDurationHours = diff.inSeconds / 3600.0;
              }
            }

            double historicalDurationHours = historicalDurationMinutes / 60.0;
            double totalDurationHours = historicalDurationHours + liveDurationHours;
            
            int totalMins = (totalDurationHours * 60).floor();
            String totalTimeStr = "${totalMins ~/ 60}j ${totalMins % 60}m";

            // Arus Rata-rata (gunakan nilai live jika > 0, jika tidak gunakan estimasi)
            double avgAmpere = currentAmpere > 0 ? currentAmpere : (type == 'Washer' ? 0.6 : 1.2);

            // Hitung kWh dan biaya total bulan ini
            final energyKwh = (220.0 * avgAmpere * totalDurationHours) / 1000.0;
            final cost = energyKwh * 1500.0; // Asumsi Rp 1.500/kWh

            return Container(
              width: 185,
          margin: const EdgeInsets.only(right: 12, top: 4, bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isActive ? accentColor.withOpacity(0.5) : (isDark ? Colors.grey[800]! : Colors.grey[300]!)),
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: 15,
                spreadRadius: 2,
              ),
              if (!isDark && !isActive)
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? Colors.greenAccent : Colors.grey,
                      boxShadow: isActive ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 6)] : null,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              _buildStatRowCard("Arus Rata-rata", "${avgAmpere.toStringAsFixed(2)} A", Icons.electric_meter, isDark),
              const SizedBox(height: 6),
              _buildStatRowCard("Total Waktu", totalTimeStr, Icons.timer_outlined, isDark),
              const Spacer(),
              Divider(height: 16, color: isDark ? Colors.grey[800] : Colors.grey[100]),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Energi", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      Text("${energyKwh.toStringAsFixed(2)} kWh", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[600])),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Biaya", style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      Text(NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(cost), 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        );
      }
    );
      }
    );
  }

  Widget _buildStatRowCard(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.black87)),
      ],
    );
  }
}

