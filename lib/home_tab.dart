import 'package:flutter/material.dart';
import 'package:aplikasilaundry/localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:aplikasilaundry/token_management.dart';
import 'package:aplikasilaundry/activity_log.dart';
import 'package:aplikasilaundry/store_management.dart';
import 'package:aplikasilaundry/customer_mode.dart';
import 'package:aplikasilaundry/live_machine_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart' hide Query;
import 'package:aplikasilaundry/services/api_service.dart';
class HomeTab extends StatefulWidget {
  final String? userName;
  final String userRole;
  final String? selectedStoreId;
  final List<Map<String, dynamic>> stores;
  final ValueChanged<String?> onStoreChanged;
  final VoidCallback? onViewAllMachines;

  const HomeTab({
    super.key,
    this.userName,
    required this.userRole,
    this.selectedStoreId,
    required this.stores,
    required this.onStoreChanged,
    this.onViewAllMachines,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
  String _selectedRevenuePeriod = 'Hari Ini';
  DateTime? _lastViewedActivities;

  Stream<QuerySnapshot>? _tokenBatchesStream;
  Stream<QuerySnapshot>? _transactionsStream;
  StreamController<List<Map<String, dynamic>>>? _machinesController;
  StreamSubscription? _rtdbSubscription;
  Stream<QuerySnapshot>? _activitiesStream;

  @override
  void initState() {
    super.initState();
    _initStreams();
    _loadLastViewedActivities();
  }

  @override
  void dispose() {
    _rtdbSubscription?.cancel();
    _machinesController?.close();
    super.dispose();
  }

  Future<void> _loadLastViewedActivities() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt('last_viewed_activities_${widget.selectedStoreId ?? "ALL"}');
    if (timestamp != null) {
      if (mounted) {
        setState(() {
          _lastViewedActivities = DateTime.fromMillisecondsSinceEpoch(timestamp);
        });
      }
    }
  }

  Future<void> _markActivitiesAsViewed() async {
    final now = DateTime.now();
    setState(() {
      _lastViewedActivities = now;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_viewed_activities_${widget.selectedStoreId ?? "ALL"}', now.millisecondsSinceEpoch);
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedStoreId != widget.selectedStoreId) {
      _initStreams();
      _loadLastViewedActivities();
    }
  }

  void _initStreams() {
    // 1. Token Batches Stream
    if (widget.userRole == 'Superadmin' || widget.userRole == 'Admin') {
      _tokenBatchesStream = FirebaseFirestore.instance.collectionGroup('token_batches').where('remaining_tokens', isGreaterThan: 0).snapshots();
    } else if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
      _tokenBatchesStream = FirebaseFirestore.instance.collection('stores').doc(widget.selectedStoreId).collection('token_batches').where('remaining_tokens', isGreaterThan: 0).snapshots();
    } else {
      _tokenBatchesStream = null;
    }

    // 2. Transactions Stream (Fetch from start of previous year)
    DateTime now = DateTime.now();
    DateTime fetchStart = DateTime(now.year - 1, 1, 1);
    Query txQuery = FirebaseFirestore.instance.collection('transactions')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(fetchStart));
    _transactionsStream = txQuery.snapshots();

    // 3. Machines Stream
    _rtdbSubscription?.cancel();
    if (widget.selectedStoreId != null) {
      if (_machinesController == null || _machinesController!.isClosed) {
        _machinesController = StreamController<List<Map<String, dynamic>>>.broadcast();
        setState(() {});
      }
      _fetchAndListenMachines();
    } else {
      _machinesController?.close();
      _machinesController = null;
      setState(() {});
    }

    // 4. Activities Stream
    Query actQuery = FirebaseFirestore.instance.collection('activities');
    _activitiesStream = actQuery.orderBy('timestamp', descending: true).limit(30).snapshots();
  }

  void _fetchAndListenMachines() async {
    String? storeIdForApi = (widget.selectedStoreId == 'ALL') ? null : widget.selectedStoreId;
    
    // 1. Fetch from Laravel
    List<Map<String, dynamic>> mysqlMachines = await ApiService().getMachines(storeId: storeIdForApi);

    if (mysqlMachines.isEmpty) {
      if (_machinesController != null && !_machinesController!.isClosed) {
        _machinesController?.add([]);
      }
    } else {
      if (_machinesController != null && !_machinesController!.isClosed) {
        _machinesController?.add(List.from(mysqlMachines));
      }
    }

    // 2. Listen to RTDB
    _rtdbSubscription = FirebaseDatabase.instance.ref('machines').onValue.listen((event) {
      if (event.snapshot.value != null && mysqlMachines.isNotEmpty) {
        final rtdbData = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        for (var i = 0; i < mysqlMachines.length; i++) {
          final mId = mysqlMachines[i]['id'].toString();
          final rtdbKey = 'Mesin$mId';
          if (rtdbData.containsKey(rtdbKey)) {
            final statusData = Map<String, dynamic>.from(rtdbData[rtdbKey] as Map);
            mysqlMachines[i]['status'] = statusData['status'] ?? mysqlMachines[i]['status'];
            mysqlMachines[i]['relay_status'] = statusData['relay_status'] ?? mysqlMachines[i]['relay_status'];
            mysqlMachines[i]['timer_enabled'] = statusData['timer_enabled'];
            mysqlMachines[i]['duration_minutes'] = statusData['duration_minutes'];
            mysqlMachines[i]['start_time'] = statusData['start_time'];
            if (statusData.containsKey('current_ampere')) {
              mysqlMachines[i]['current_ampere'] = statusData['current_ampere'];
            } else if (statusData.containsKey('current')) {
              mysqlMachines[i]['current_ampere'] = statusData['current'];
            }
            if (statusData.containsKey('dryer_remaining_minutes')) {
              mysqlMachines[i]['dryer_remaining_minutes'] = statusData['dryer_remaining_minutes'];
            }
          }
        }
        if (_machinesController != null && !_machinesController!.isClosed) {
            _machinesController?.add(List.from(mysqlMachines));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedStoreId == null && widget.stores.isEmpty) {
      return _buildEmptyState(context);
    }

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildStoreSelector(context),
            const SizedBox(height: 24),
            _buildSisaTokenCard(context),
            const SizedBox(height: 24),
            _buildPendapatanWidget(context),
            const SizedBox(height: 24),
            _buildStatusMesin(context),
            _buildMachineList(),
            const SizedBox(height: 24),
            _buildAktivitasTerbaru(context),
            const SizedBox(height: 100), // Ruang ekstra untuk FAB
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_outlined, size: 80, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 32),
              Text(
                AppLocalizations.tr('welcome_workspace'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.tr('no_store_desc'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              if (widget.userRole == 'Superadmin' || widget.userRole == 'Admin' || widget.userRole == 'Owner')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => StoreManagementPage(currentRole: widget.userRole)),
                    );
                  },
                  icon: const Icon(Icons.add_business, color: Colors.white),
                  label: Text(AppLocalizations.tr('add_new_store'), style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = widget.userName ?? user?.displayName ?? AppLocalizations.tr('user');

    final hour = DateTime.now().hour;
    String greeting = AppLocalizations.tr('greeting_night');
    if (hour >= 5 && hour < 12) {
      greeting = AppLocalizations.tr('greeting_morning');
    } else if (hour >= 12 && hour < 15) {
      greeting = AppLocalizations.tr('greeting_afternoon');
    } else if (hour >= 15 && hour < 18) {
      greeting = AppLocalizations.tr('greeting_evening');
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: NetworkImage(user?.photoURL ?? 'https://ui-avatars.com/api/?name=User&background=0F3460&color=fff'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("👋 " + greeting + ",", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 4),
              Text(displayName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(widget.userRole, style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('activities')
              .where('timestamp', isGreaterThan: Timestamp.fromDate(
                  _lastViewedActivities != null && _lastViewedActivities!.isAfter(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) 
                      ? _lastViewedActivities! 
                      : DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
              ))
              .snapshots(),
          builder: (context, snapshot) {
            int count = 0;
            if (snapshot.hasData) {
              count = snapshot.data!.docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                if (widget.userRole == 'Superadmin' || widget.userRole == 'Owner') {
                  // Superadmin/Owner sees all stores they own
                  List<String> myStoreIds = widget.stores.map((s) => s['id'] as String).toList();
                  return myStoreIds.contains(data['store_id']);
                }
                return data['store_id'] == widget.selectedStoreId;
              }).length;
            }

            return GestureDetector(
              onTap: () {
                _markActivitiesAsViewed();
                Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityLogPage(initialStoreId: widget.selectedStoreId, stores: widget.stores, userRole: widget.userRole)));
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const IconButton(
                    icon: Icon(Icons.notifications_outlined, size: 28),
                    onPressed: null, // Disabled inside GestureDetector
                  ),
                  if (count > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(count > 99 ? "99+" : "$count", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            );
          }
        ),
      ],
    );
  }

  Widget _buildStoreSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.stores.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.tr('choose_branch'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: widget.selectedStoreId,
              icon: const Icon(Icons.keyboard_arrow_down),
              hint: Text(AppLocalizations.tr('choose_branch')),
              items: widget.stores.map((store) {
                return DropdownMenuItem<String>(
                  value: store['id'],
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.storefront, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(store['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(AppLocalizations.tr('branch_not_set'), style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: widget.onStoreChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSisaTokenCard(BuildContext context) {
    if (_tokenBatchesStream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _tokenBatchesStream,
      builder: (context, snapshot) {
        int tokenBalance = 0;
        DateTime? maxExpired;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final remaining = data['remaining_tokens'] as int? ?? 0;
            DateTime? expiredAt;
            if (data.containsKey('expired_at') && data['expired_at'] != null) {
              expiredAt = (data['expired_at'] as Timestamp).toDate();
              if (DateTime.now().isBefore(expiredAt)) {
                tokenBalance += remaining;
                if (maxExpired == null || expiredAt.isAfter(maxExpired)) maxExpired = expiredAt;
              }
            } else {
              tokenBalance += remaining;
            }
          }
        }

        String expiredText = maxExpired != null ? "Berlaku sampai ${DateFormat('dd MMMM yyyy', 'id_ID').format(maxExpired)}" : AppLocalizations.tr('valid_forever');

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => TokenManagementPage(currentRole: widget.userRole, selectedStoreId: widget.selectedStoreId)));
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4338CA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF4338CA).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.tr('token_balance'), style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                      child: Row(children: [Icon(Icons.star, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(AppLocalizations.tr('premium_package'), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("$tokenBalance", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.0)),
                    const SizedBox(width: 8),
                    Padding(padding: EdgeInsets.only(bottom: 8.0), child: Text(AppLocalizations.tr('token'), style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Text(expiredText, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildPendapatanWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime now = DateTime.now();

    String activePeriod = widget.userRole == 'Cashier' ? 'Hari Ini' : _selectedRevenuePeriod;

    return StreamBuilder<QuerySnapshot>(
      stream: _transactionsStream,
      builder: (context, snapshot) {
        double currentIncome = 0;
        double previousIncome = 0;
        
        Map<int, double> dailyIncome30 = {};
        for (int i = 0; i < 30; i++) dailyIncome30[i] = 0;
        double maxDaily30 = 20;

        Map<int, double> monthlyIncome = {};
        for (int i = 1; i <= 12; i++) monthlyIncome[i] = 0;
        double maxMonthly = 20;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;

            if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
              if (data['store_id'] != widget.selectedStoreId) continue;
            } else if (widget.userRole == 'Owner') {
              List<String> myStoreIds = widget.stores.map((s) => s['id'] as String).toList();
              if (!myStoreIds.contains(data['store_id'])) continue;
            }

            final amountRaw = data['amount'] ?? 0;
            final amount = double.tryParse(amountRaw.toString()) ?? 0.0;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
            if (timestamp != null) {
              DateTime startOfToday = DateTime(now.year, now.month, now.day);
              DateTime startOfYesterday = startOfToday.subtract(const Duration(days: 1));
              
              if (activePeriod == 'Hari Ini') {
                if (timestamp.isAfter(startOfToday) || timestamp.isAtSameMomentAs(startOfToday)) {
                  currentIncome += amount;
                } else if (timestamp.isAfter(startOfYesterday) && timestamp.isBefore(startOfToday)) {
                  previousIncome += amount;
                }
              } else if (activePeriod == 'Bulan Ini') {
                DateTime thirtyDaysAgo = startOfToday.subtract(const Duration(days: 29));
                DateTime sixtyDaysAgo = startOfToday.subtract(const Duration(days: 59));
                if (timestamp.isAfter(thirtyDaysAgo) || timestamp.isAtSameMomentAs(thirtyDaysAgo)) {
                  currentIncome += amount;
                  final diff = startOfToday.difference(DateTime(timestamp.year, timestamp.month, timestamp.day)).inDays;
                  if (diff >= 0 && diff < 30) {
                    int index = 29 - diff;
                    dailyIncome30[index] = (dailyIncome30[index] ?? 0) + amount;
                    if (dailyIncome30[index]! > maxDaily30) maxDaily30 = dailyIncome30[index]!;
                  }
                } else if (timestamp.isAfter(sixtyDaysAgo) && timestamp.isBefore(thirtyDaysAgo)) {
                  previousIncome += amount;
                }
              } else if (activePeriod == 'Tahun Ini') {
                if (timestamp.year == now.year) {
                  currentIncome += amount;
                  monthlyIncome[timestamp.month] = (monthlyIncome[timestamp.month] ?? 0) + amount;
                  if (monthlyIncome[timestamp.month]! > maxMonthly) maxMonthly = monthlyIncome[timestamp.month]!;
                } else if (timestamp.year == now.year - 1) {
                  previousIncome += amount;
                }
              }
            }
          }
        }

        double percentChange = 0;
        if (previousIncome > 0) {
          percentChange = ((currentIncome - previousIncome) / previousIncome) * 100;
        } else if (currentIncome > 0) {
          percentChange = 100;
        }
        bool isUp = percentChange >= 0;
        
        String previousLabel = "";
        if (activePeriod == 'Hari Ini') previousLabel = "Dari kemarin";
        else if (activePeriod == 'Bulan Ini') previousLabel = "Dari bulan lalu";
        else if (activePeriod == 'Tahun Ini') previousLabel = "Dari tahun lalu";

        List<FlSpot> spots = [];
        double minX = 0;
        double maxX = 6;
        double maxY = 6;
        
        if (activePeriod == 'Hari Ini') {
          spots = const [FlSpot(0.0, 1.0), FlSpot(1.0, 2.0), FlSpot(2.0, 1.5), FlSpot(3.0, 3.0), FlSpot(4.0, 2.5), FlSpot(5.0, 4.0), FlSpot(6.0, 5.0)];
          maxX = 6;
          maxY = 6;
        } else if (activePeriod == 'Bulan Ini') {
          minX = 0;
          maxX = 29;
          for (int i = 0; i < 30; i++) {
            spots.add(FlSpot(i.toDouble(), dailyIncome30[i]!));
          }
          maxY = maxDaily30 > 0 ? maxDaily30 * 1.2 : 20;
        } else if (activePeriod == 'Tahun Ini') {
          minX = 1;
          maxX = 12;
          for (int i = 1; i <= 12; i++) {
            spots.add(FlSpot(i.toDouble(), monthlyIncome[i]!));
          }
          maxY = maxMonthly > 0 ? maxMonthly * 1.2 : 20;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            activePeriod == 'Hari Ini' ? "Pendapatan Hari Ini" : 
                            activePeriod == 'Bulan Ini' ? "Pendapatan 30 Hari" : "Pendapatan Tahun Ini", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? Colors.green : Colors.red, size: 16),
                        Text("${percentChange.abs().toStringAsFixed(1)}%", style: TextStyle(color: isUp ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  if (widget.userRole != 'Cashier')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRevenuePeriod,
                          isDense: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF2563EB)),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                          borderRadius: BorderRadius.circular(16),
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: ['Hari Ini', 'Bulan Ini', 'Tahun Ini'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedRevenuePeriod = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatter.format(currentIncome), 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text("$previousLabel ${formatter.format(previousIncome)}", 
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 80,
                    height: 50,
                    child: LineChart(
                      LineChartData(
                        lineTouchData: const LineTouchData(enabled: false),
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: minX, maxX: maxX, minY: 0, maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true, color: Colors.blue, barWidth: 3, isStrokeCapRound: true, dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(colors: [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatusMesin(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _machinesController?.stream,
      builder: (context, snapshot) {
        int washerActive = 0;
        int washerIdle = 0;
        int dryerActive = 0;
        int dryerIdle = 0;

        if (snapshot.hasData) {
          for (var data in snapshot.data!) {
            final type = data['type']?.toString() ?? 'Washer';
            final status = data['status']?.toString() ?? 'Idle';
            
            if (type == 'Washer') {
              if (status == 'Active') washerActive++; else washerIdle++;
            } else {
              if (status == 'Active') dryerActive++; else dryerIdle++;
            }
          }
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.tr('machine_status'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                GestureDetector(
                  onTap: widget.onViewAllMachines,
                  child: Text(AppLocalizations.tr('see_all'), style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallStatusCard(context, AppLocalizations.tr('washer_active'), washerActive, Colors.green),
                _buildSmallStatusCard(context, AppLocalizations.tr('washer_idle'), washerIdle, isDark ? Colors.white : Colors.black87),
                _buildSmallStatusCard(context, AppLocalizations.tr('dryer_active'), dryerActive, Colors.green),
                _buildSmallStatusCard(context, AppLocalizations.tr('dryer_idle'), dryerIdle, isDark ? Colors.white : Colors.black87),
              ],
            ),
          ],
        );
      }
    );
  }

  Widget _buildMachineList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _machinesController?.stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final machines = snapshot.data!;
        
        return Column(
          children: [
            const SizedBox(height: 16),
            ...machines.map((data) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: LiveMachineItem(data: data),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSmallStatusCard(BuildContext context, String title, int count, Color titleColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(fontSize: 10, color: titleColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("$count", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: titleColor == Colors.green ? Colors.green : (isDark ? Colors.white : Colors.black87))),
          ],
        ),
      ),
    );
  }



  Widget _buildAktivitasTerbaru(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.tr('recent_activity'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            GestureDetector(
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityLogPage(initialStoreId: widget.selectedStoreId, stores: widget.stores, userRole: widget.userRole)));
              },
              child: Text(AppLocalizations.tr('see_all'), style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: _activitiesStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(child: Text(AppLocalizations.tr('no_activity'), style: TextStyle(color: Colors.grey)));
            }
            
            var docs = snapshot.data!.docs;
            // FILTER LOKAL
            if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
              docs = docs.where((d) => (d.data() as Map<String, dynamic>)['store_id'] == widget.selectedStoreId).toList();
            } else if (widget.userRole == 'Owner') {
              List<String> myStoreIds = widget.stores.map((s) => s['id'] as String).toList();
              docs = docs.where((d) => myStoreIds.contains((d.data() as Map<String, dynamic>)['store_id'])).toList();
            }

            if (docs.isEmpty) {
              return Center(child: Text(AppLocalizations.tr('no_activity'), style: TextStyle(color: Colors.grey)));
            }
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: docs.take(3).map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  String action = data['action'] ?? 'Aktivitas Baru';
                  Timestamp? timestamp = data['timestamp'] as Timestamp?;
                  String timeText = AppLocalizations.tr('just_now');
                  if (timestamp != null) {
                    final diff = DateTime.now().difference(timestamp.toDate());
                    if (diff.inMinutes < 60) {
                      timeText = "${diff.inMinutes} menit lalu";
                    } else if (diff.inHours < 24) {
                      timeText = "${diff.inHours} jam lalu";
                    } else {
                      timeText = "${diff.inDays} hari lalu";
                    }
                  }
                  
                  IconData icon = Icons.info_outline;
                  Color iconColor = Colors.green;
                  String actionLower = action.toLowerCase();
                  if (actionLower.contains("selesai") || actionLower.contains("mesin") || actionLower.contains("washer") || actionLower.contains("dryer")) {
                     icon = Icons.local_laundry_service;
                     iconColor = Colors.orange;
                  }
                  if (actionLower.contains("qris") || actionLower.contains("bayar") || actionLower.contains("pembayaran") || actionLower.contains("transaksi")) { 
                     icon = Icons.payments_outlined; 
                     iconColor = Colors.blue; 
                  }
                  if (actionLower.contains("token")) { 
                     icon = Icons.monetization_on_outlined; 
                     iconColor = Colors.teal; 
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    title: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(timeText, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  );
                }).toList(),
              ),
            );
          }
        ),
      ],
    );
  }
}
