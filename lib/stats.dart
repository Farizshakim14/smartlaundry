import 'package:aplikasilaundry/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/services/api_service.dart';

class StatsPage extends StatefulWidget {
  final String? selectedStoreId;
  final String userRole;
  final List<Map<String, dynamic>> myStores;
  
  const StatsPage({
    super.key, 
    this.selectedStoreId,
    this.userRole = 'Unknown',
    this.myStores = const [],
  });

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  String? _selectedFilterStoreId; // null = Semua Cabang
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTransactions = [];
  int _totalIncome = 0;
  int _totalExpense = 0;

  @override
  void initState() {
    super.initState();
    // Jika kasir, paksa ke store_id yang dipilih di awal
    if (widget.userRole == 'Cashier') {
      _selectedFilterStoreId = widget.selectedStoreId;
    }
    _fetchData();
  }

  @override
  void didUpdateWidget(StatsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userRole == 'Cashier' && oldWidget.selectedStoreId != widget.selectedStoreId) {
      _selectedFilterStoreId = widget.selectedStoreId;
      _fetchData();
    }
  }

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

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    List<Map<String, dynamic>> tempTransactions = [];
    int tempIncome = 0;
    int tempExpense = 0;

    String? storeIdParam = _selectedFilterStoreId;
    if (storeIdParam == null && widget.userRole == 'Owner') {
      List<String> myStoreIds = widget.myStores.map((s) => s['id'] as String).toList();
      if (myStoreIds.isNotEmpty) {
        storeIdParam = myStoreIds.join(',');
      } else {
        storeIdParam = 'TIDAK_ADA';
      }
    }

    final machineTxs = await ApiService().getTransactions(storeId: storeIdParam);
    for (var tx in machineTxs) {
      final int amount = (tx['cost'] ?? 0) as int;
      tempIncome += amount;
      DateTime? date = tx['created_at'] != null ? DateTime.tryParse(tx['created_at'].toString()) : null;
      String mName = (tx['machine'] != null && tx['machine']['name'] != null) ? tx['machine']['name'] : 'Mesin';
      
      tempTransactions.add({
        'title': "Pemakaian - $mName",
        'date': date,
        'amountStr': "+ Rp ${_formatRupiahPositive(amount)}",
        'rawAmount': amount,
        'isIncome': true,
        'isManual': false,
        'timestamp': date,
      });
    }

    final manualTxs = await ApiService().getManualTransactions(storeId: storeIdParam);
    for (var tx in manualTxs) {
      final int amount = (tx['amount'] ?? 0) as int;
      final bool isIncome = tx['type'] == 'income';
      if (isIncome) tempIncome += amount; else tempExpense += amount;
      DateTime? date = tx['timestamp'] != null ? DateTime.tryParse(tx['timestamp'].toString()) : null;
      
      tempTransactions.add({
        'docId': tx['id'].toString(),
        'title': tx['title'] ?? (isIncome ? 'Pemasukan Manual' : 'Pengeluaran Manual'),
        'date': date,
        'amountStr': "${isIncome ? '+' : '-'} Rp ${_formatRupiahPositive(amount)}",
        'rawAmount': amount,
        'isIncome': isIncome,
        'isManual': true,
        'timestamp': date,
      });
    }

    try {
      Query q = FirebaseFirestore.instance.collection('token_requests').where('status', isEqualTo: 'Approved');
      if (_selectedFilterStoreId != null) {
        q = q.where('store_id', isEqualTo: _selectedFilterStoreId);
      } else {
        List<String> myStoreIds = widget.myStores.map((s) => s['id'] as String).toList();
        if (myStoreIds.isEmpty) q = q.where('store_id', isEqualTo: 'TIDAK_ADA');
        else {
          if (myStoreIds.length > 10) myStoreIds = myStoreIds.sublist(0, 10);
          q = q.where('store_id', whereIn: myStoreIds);
        }
      }
      final tokenSnap = await q.get();
      for (var doc in tokenSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final int price = data['price'] ?? 0;
        
        bool isSuperadmin = widget.userRole == 'Superadmin';
        
        if (isSuperadmin) {
          tempIncome += price;
        } else {
          tempExpense += price;
        }
        
        DateTime? date = data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : null;
        tempTransactions.add({
          'title': isSuperadmin ? "Jual Token - ${data['package_name'] ?? 'Paket'}" : "Beli Token - ${data['package_name'] ?? 'Paket'}",
          'date': date,
          'amountStr': "${isSuperadmin ? '+' : '-'} Rp ${_formatRupiahPositive(price)}",
          'rawAmount': price,
          'isIncome': isSuperadmin,
          'isManual': false,
          'timestamp': date,
        });
      }
    } catch (e) {}

    tempTransactions.sort((a, b) {
      final timeA = a['timestamp'] as DateTime?;
      final timeB = b['timestamp'] as DateTime?;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });

    if (mounted) {
      setState(() {
        _allTransactions = tempTransactions;
        _totalIncome = tempIncome;
        _totalExpense = tempExpense;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.selectedStoreId == null && widget.userRole == 'Cashier') {
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
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        "Stats",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (widget.userRole == 'Owner')
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.3)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedFilterStoreId,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2563EB)),
                                borderRadius: BorderRadius.circular(16),
                                dropdownColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                                hint: Text("Semua Cabang", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w600, fontSize: 14),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text("Semua Cabang"),
                                  ),
                                  ...widget.myStores.map((store) {
                                    return DropdownMenuItem<String?>(
                                      value: store['id'],
                                      child: Text(store['name'] ?? 'Unknown Store', overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _selectedFilterStoreId = val;
                                  });
                                  _fetchData();
                                },
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.userRole == 'Owner')
                  IconButton(
                    onPressed: () {
                      if (_selectedFilterStoreId == null) {
                        CustomSnackbar.show(context, const SnackBar(content: Text("Pilih salah satu cabang terlebih dahulu untuk menambah transaksi manual.")));
                        return;
                      }
                      _showAddTransactionDialog(context, isDark);
                    },
                    icon: const Icon(Icons.add_circle, size: 28),
                    color: const Color(0xFF2563EB),
                    tooltip: "Tambah Transaksi Manual",
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    int totalBalance = _totalIncome - _totalExpense;
    
    if (widget.userRole == 'Cashier') {
      final now = DateTime.now();
      final cashierTxs = _allTransactions.where((t) {
        if (t['date'] == null) return false;
        DateTime date = t['date'] as DateTime;
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();
      
      int todayQris = 0;
      int todayCash = 0;
      int todayExpense = 0;

      for (var t in cashierTxs) {
        if (t['isIncome'] == true) {
          if (t['isManual'] == true) {
            todayCash += (t['rawAmount'] ?? 0) as int;
          } else {
            todayQris += (t['rawAmount'] ?? 0) as int;
          }
        } else {
          todayExpense += (t['rawAmount'] ?? 0) as int;
        }
      }
      
      return _buildCashierView(context, cashierTxs, todayQris, todayCash, todayExpense, isDark);
    } else {
      return _buildOwnerView(context, _allTransactions, _totalIncome, _totalExpense, totalBalance, isDark);
    }
  }

  Widget _buildCashierView(BuildContext context, List<Map<String, dynamic>> allTransactions, int todayQris, int todayCash, int todayExpense, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Laporan Shift Hari Ini",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          // Ringkasan Kasir
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Setoran Tunai (Manual)", style: TextStyle(color: Colors.grey)),
                    Text(_formatRupiah(todayCash), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Masuk ke QRIS (Sistem)", style: TextStyle(color: Colors.grey)),
                    Text(_formatRupiah(todayQris), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Pengeluaran (Kasbon dll)", style: TextStyle(color: Colors.grey)),
                    Text(_formatRupiah(todayExpense), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "Riwayat Transaksi Shift Ini",
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
                child: Text("Belum ada transaksi hari ini", style: TextStyle(color: Colors.grey)),
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
  }

  Widget _buildOwnerView(BuildContext context, List<Map<String, dynamic>> allTransactions, int totalIncome, int totalExpense, int totalBalance, bool isDark) {
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
                Text(
                  _selectedFilterStoreId == null ? "Laba Bersih Keseluruhan (Semua Cabang)" : "Laba Bersih Cabang",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                      title: "Pemasukan",
                      amount: _formatRupiah(totalIncome),
                      icon: Icons.arrow_downward,
                      color: const Color(0xFF10B981), // Hijau
                    ),
                    Container(width: 1, height: 40, color: Colors.white30),
                    _buildIncomeExpenseMini(
                      title: "Pengeluaran",
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
            onPressed: () async {
              Navigator.pop(context);
              final success = await ApiService().deleteManualTransaction(docId);
              if (success) {
                if (mounted) _fetchData();
              } else {
                if (mounted) CustomSnackbar.show(context, const SnackBar(content: Text("Gagal menghapus")));
              }
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
                            CustomSnackbar.show(context, 
                              const SnackBar(content: Text("Harap isi semua kolom")),
                            );
                            return;
                          }
                          
                          final int? amount = int.tryParse(amountText);
                          if (amount == null || amount <= 0) {
                            CustomSnackbar.show(context, 
                              const SnackBar(content: Text("Nominal tidak valid")),
                            );
                            return;
                          }

                          setState(() => isLoading = true);

                          try {
                            String targetStore = _selectedFilterStoreId ?? widget.selectedStoreId ?? '';
                            if (targetStore.isEmpty) {
                              CustomSnackbar.show(context, const SnackBar(content: Text("Pilih toko dulu")));
                              if (context.mounted) setState(() => isLoading = false);
                              return;
                            }
                            
                            Map<String, dynamic> result;
                            if (docId == null) {
                              result = await ApiService().addManualTransaction(targetStore, title, amount, selectedType);
                            } else {
                              result = await ApiService().updateManualTransaction(docId, title, amount, selectedType);
                            }
                            
                            if (context.mounted) {
                              if (result['success']) {
                                Navigator.pop(context);
                                CustomSnackbar.show(context, SnackBar(content: Text("Transaksi tersimpan")));
                                _fetchData();
                              } else {
                                CustomSnackbar.show(context, SnackBar(content: Text("Gagal: ${result['message']}")));
                              }
                            }
                          } catch (e) {
                            if (context.mounted) CustomSnackbar.show(context, SnackBar(content: Text("Gagal: $e")));
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

