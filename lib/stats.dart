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
            child: Text(
              "Statistics",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
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
                    if (transSnap.hasError || tokenSnap.hasError) {
                      return const Center(child: Text("Terjadi kesalahan memuat data."));
                    }
                    if (transSnap.connectionState == ConnectionState.waiting && !transSnap.hasData) {
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
                          'timestamp': data['created_at'],
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
                                title: trx['title'],
                                date: trx['date'] != null ? _formatDate(trx['date']) : 'Unknown Date',
                                amount: trx['amountStr'],
                                isIncome: trx['isIncome'],
                                isDark: isDark,
                              );
                            }),
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
    required String title,
    required String date,
    required String amount,
    required bool isIncome,
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
        ],
      ),
    );
  }
}
