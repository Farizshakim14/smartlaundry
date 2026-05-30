import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsPage extends StatelessWidget {
  final String? selectedStoreId;
  const StatsPage({super.key, this.selectedStoreId});

  String _formatRupiah(int amount) {
    if (amount < 0) {
      return "- Rp ${_formatRupiahPositive(amount.abs())}";
    }
    return "Rp ${_formatRupiahPositive(amount)}";
  }

  String _formatRupiahPositive(int amount) {
    String res = amount.toString();
    String result = "";
    int count = 0;
    for (int i = res.length - 1; i >= 0; i--) {
      if (count == 3) {
        result = ".$result";
        count = 0;
      }
      result = res[i] + result;
      count++;
    }
    return result;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return "${date.day} ${months[date.month - 1]} ${date.year}, $h:$m";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (selectedStoreId == null) {
      return const SafeArea(
        child: Center(child: Text("Pilih toko di Dashboard terlebih dahulu.", style: TextStyle(color: Colors.grey))),
      );
    }

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
                  "Statistics",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => _showAddTransactionDialog(context, isDark),
                  icon: const Icon(Icons.add_circle, size: 28),
                  color: const Color(0xFF2563EB),
                  tooltip: "Tambah Transaksi Manual",
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('store_id', isEqualTo: selectedStoreId)
                  .snapshots(),
              builder: (context, transSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('token_requests')
                      .where('store_id', isEqualTo: selectedStoreId)
                      .where('status', isEqualTo: 'Approved')
                      .snapshots(),
                  builder: (context, tokenSnap) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('manual_transactions')
                          .where('store_id', isEqualTo: selectedStoreId)
                          .snapshots(),
                      builder: (context, manualSnap) {
                        if (transSnap.hasError || tokenSnap.hasError || manualSnap.hasError) {
                          return const Center(child: Text("Terjadi kesalahan memuat data."));
                        }
                        
                        final bool transWaiting = transSnap.connectionState == ConnectionState.waiting && !transSnap.hasData;
                        final bool tokenWaiting = tokenSnap.connectionState == ConnectionState.waiting && !tokenSnap.hasData;
                        final bool manualWaiting = manualSnap.connectionState == ConnectionState.waiting && !manualSnap.hasData;
                        
                        if (transWaiting && tokenWaiting && manualWaiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        int totalIncome = 0;
                        int totalExpense = 0;
                        List<Map<String, dynamic>> allTransactions = [];

                    // Proses Transaksi Pemasukan (Mesin)
                    if (transSnap.hasData) {
                      for (var doc in transSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final int amount = data['amount'] ?? 0;
                        totalIncome += amount;
                        
                        DateTime? date;
                        if (data['timestamp'] != null) {
                          date = (data['timestamp'] as Timestamp).toDate();
                        }
                        
                        allTransactions.add({
                          'title': "Pemakaian - ${data['machine_name'] ?? 'Mesin'}",
                          'date': date,
                          'amountStr': "+ Rp ${_formatRupiahPositive(amount)}",
                          'isIncome': true,
                          'isManual': false,
                          'timestamp': data['timestamp'],
                        });
                      }
                    }

                    // Proses Transaksi Pengeluaran (Beli Token)
                    if (tokenSnap.hasData) {
                      for (var doc in tokenSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final int price = data['price'] ?? 0;
                        totalExpense += price;
                        
                        DateTime? date;
                        if (data['created_at'] != null) {
                          date = (data['created_at'] as Timestamp).toDate();
                        }
                        
                        allTransactions.add({
                          'title': "Beli Token - ${data['package_name'] ?? 'Paket'}",
                          'date': date,
                          'amountStr': "- Rp ${_formatRupiahPositive(price)}",
                          'isIncome': false,
                          'isManual': false,
                          'timestamp': data['created_at'],
                        });
                      }
                    }

                    // Proses Transaksi Manual
                    if (manualSnap.hasData) {
                      for (var doc in manualSnap.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final int amount = data['amount'] ?? 0;
                        final bool isIncome = data['type'] == 'income';
                        
                        if (isIncome) {
                          totalIncome += amount;
                        } else {
                          totalExpense += amount;
                        }
                        
                        DateTime? date;
                        if (data['timestamp'] != null) {
                          date = (data['timestamp'] as Timestamp).toDate();
                        }
                        
                        allTransactions.add({
                          'docId': doc.id,
                          'title': data['title'] ?? (isIncome ? 'Pemasukan Manual' : 'Pengeluaran Manual'),
                          'date': date,
                          'amountStr': "${isIncome ? '+' : '-'} Rp ${_formatRupiahPositive(amount)}",
                          'rawAmount': amount,
                          'isIncome': isIncome,
                          'isManual': true,
                          'timestamp': data['timestamp'],
                        });
                      }
                    }

                    final int totalBalance = totalIncome - totalExpense;

                    // Sort transaksi berdasarkan waktu terbaru (descending)
                    allTransactions.sort((a, b) {
                      final timeA = a['timestamp'] as Timestamp?;
                      final timeB = b['timestamp'] as Timestamp?;
                      if (timeA == null && timeB == null) return 0;
                      if (timeA == null) return 1;
                      if (timeB == null) return -1;
                      return timeB.compareTo(timeA);
                    });

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Saldo Utama
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Total Balance",
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatRupiah(totalBalance),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildIncomeExpenseMini(
                                      title: "Income",
                                      amount: _formatRupiah(totalIncome),
                                      icon: Icons.arrow_downward,
                                      color: const Color(0xFF10B981), // Hijau
                                    ),
                                    Container(width: 1, height: 40, color: Colors.white30),
                                    _buildIncomeExpenseMini(
                                      title: "Expense",
                                      amount: _formatRupiah(totalExpense),
                                      icon: Icons.arrow_upward,
                                      color: const Color(0xFFEF4444), // Merah
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Transaksi Terbaru
                          Text(
                            "Recent Transactions",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          if (allTransactions.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Text("Belum ada transaksi", style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          else
                            ...allTransactions.map((trx) {
                              return _buildTransactionItem(
                                context: context,
                                title: trx['title'],
                                date: trx['date'] != null ? _formatDate(trx['date']) : 'Unknown Date',
                                amount: trx['amountStr'],
                                rawAmount: trx['rawAmount'],
                                docId: trx['docId'],
                                isIncome: trx['isIncome'],
                                isManual: trx['isManual'] ?? false,
                                isDark: isDark,
                              );
                            }),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
        ],
      ),
    );
  }

  Widget _buildIncomeExpenseMini({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem({
    required BuildContext context,
    required String title,
    required String date,
    required String amount,
    int? rawAmount,
    String? docId,
    required bool isIncome,
    required bool isManual,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isIncome ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFEF4444).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.account_balance_wallet : Icons.shopping_cart,
              color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              fontSize: 15,
            ),
          ),
          if (isManual && docId != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddTransactionDialog(
                    context, 
                    isDark, 
                    docId: docId, 
                    initialTitle: title, 
                    initialAmount: rawAmount, 
                    initialType: isIncome ? 'income' : 'expense',
                  );
                } else if (value == 'delete') {
                  _confirmDelete(context, docId);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text("Edit")),
                const PopupMenuItem(value: 'delete', child: Text("Hapus")),
              ],
            )
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Transaksi"),
        content: const Text("Apakah Anda yakin ingin menghapus transaksi ini?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('manual_transactions').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(
    BuildContext context, 
    bool isDark, {
    String? docId,
    String? initialTitle,
    int? initialAmount,
    String? initialType,
  }) {
    String selectedType = initialType ?? 'income'; // default to pemasukan
    final TextEditingController titleController = TextEditingController(text: initialTitle);
    final TextEditingController amountController = TextEditingController(text: initialAmount?.toString());
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                docId == null ? "Tambah Transaksi Manual" : "Edit Transaksi Manual",
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segmented Control for Type
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => selectedType = 'income'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedType == 'income'
                                    ? const Color(0xFF10B981)
                                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Pemasukan",
                                style: TextStyle(
                                  color: selectedType == 'income'
                                      ? Colors.white
                                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => selectedType = 'expense'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selectedType == 'expense'
                                    ? const Color(0xFFEF4444)
                                    : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "Pengeluaran",
                                style: TextStyle(
                                  color: selectedType == 'expense'
                                      ? Colors.white
                                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Keterangan
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Keterangan (contoh: Jual Deterjen)",
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Nominal
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Nominal (Rp)",
                        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final amountText = amountController.text.trim();
                          
                          if (title.isEmpty || amountText.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Harap isi semua kolom")),
                            );
                            return;
                          }
                          
                          final int? amount = int.tryParse(amountText);
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Nominal tidak valid")),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            if (docId == null) {
                              await FirebaseFirestore.instance.collection('manual_transactions').add({
                                'store_id': selectedStoreId,
                                'title': title,
                                'amount': amount,
                                'type': selectedType,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            } else {
                              await FirebaseFirestore.instance.collection('manual_transactions').doc(docId).update({
                                'title': title,
                                'amount': amount,
                                'type': selectedType,
                              });
                            }
                            
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(docId == null ? "Transaksi berhasil ditambahkan" : "Transaksi berhasil diubah")),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Gagal menyimpan data: $e")),
                              );
                            }
                          } finally {
                            if (context.mounted) setState(() => isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Simpan", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
