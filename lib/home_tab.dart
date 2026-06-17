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
            _buildPendapatanHariIni(context),
            const SizedBox(height: 24),
            _buildStatusMesin(context),
            _buildMachineList(),
            const SizedBox(height: 24),
            _buildTransaksiChart(context),
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
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 28),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityLogPage(initialStoreId: widget.selectedStoreId, stores: widget.stores, userRole: widget.userRole)));
              },
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Text("5", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
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
    Stream<QuerySnapshot>? tokenStream;
    if (widget.selectedStoreId == 'ALL') {
      tokenStream = FirebaseFirestore.instance.collectionGroup('token_batches').where('remaining_tokens', isGreaterThan: 0).snapshots();
    } else if (widget.selectedStoreId != null) {
      tokenStream = FirebaseFirestore.instance.collection('stores').doc(widget.selectedStoreId).collection('token_batches').where('remaining_tokens', isGreaterThan: 0).snapshots();
    } else {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: tokenStream,
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

  Widget _buildPendapatanHariIni(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    DateTime now = DateTime.now();
    DateTime startOfYesterday = DateTime(now.year, now.month, now.day - 1);
    
    Query query = FirebaseFirestore.instance.collection('transactions')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYesterday));
    
    if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
      query = query.where('store_id', isEqualTo: widget.selectedStoreId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        double todayIncome = 0;
        double yesterdayIncome = 0;
        DateTime startOfToday = DateTime(now.year, now.month, now.day);
        
        if (snapshot.hasData) {
          for(var doc in snapshot.data!.docs) {
             final data = doc.data() as Map<String, dynamic>;
             final amount = (data['amount'] ?? 0).toDouble();
             final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
             if(timestamp != null) {
                if(timestamp.isAfter(startOfToday) || timestamp.isAtSameMomentAs(startOfToday)) {
                   todayIncome += amount;
                } else {
                   yesterdayIncome += amount;
                }
             }
          }
        }
        
        double percentChange = 0;
        if (yesterdayIncome > 0) {
          percentChange = ((todayIncome - yesterdayIncome) / yesterdayIncome) * 100;
        } else if (todayIncome > 0) {
          percentChange = 100;
        }
        
        bool isUp = percentChange >= 0;

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
                children: [
                  Text(AppLocalizations.tr('today_income'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? Colors.green : Colors.red, size: 16),
                  Text("${percentChange.abs().toStringAsFixed(1)}%", style: TextStyle(color: isUp ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(formatter.format(todayIncome), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Dari kemarin ${formatter.format(yesterdayIncome)}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                  SizedBox(
                    width: 100,
                    height: 50,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: 6,
                        minY: 0,
                        maxY: 6,
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 1),
                              FlSpot(1, 2),
                              FlSpot(2, 1.5),
                              FlSpot(3, 3),
                              FlSpot(4, 2.5),
                              FlSpot(5, 4),
                              FlSpot(6, 5),
                            ],
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.0)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatusMesin(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Query query = FirebaseFirestore.instance.collection('machines');
    if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
      query = query.where('store_id', isEqualTo: widget.selectedStoreId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int washerActive = 0;
        int washerIdle = 0;
        int dryerActive = 0;
        int dryerIdle = 0;

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
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
    Query query = FirebaseFirestore.instance.collection('machines');
    if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
      query = query.where('store_id', isEqualTo: widget.selectedStoreId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        
        return Column(
          children: [
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
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

  Widget _buildTransaksiChart(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    DateTime now = DateTime.now();
    DateTime thirtyDaysAgo = DateTime(now.year, now.month, now.day - 29);

    Query query = FirebaseFirestore.instance.collection('transactions')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo));
    
    if (widget.selectedStoreId != null && widget.selectedStoreId != 'ALL') {
      query = query.where('store_id', isEqualTo: widget.selectedStoreId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        Map<int, double> dailyIncome = {};
        for (int i = 0; i < 30; i++) { dailyIncome[i] = 0; }
        double total30Days = 0;
        double maxDaily = 20;

        if (snapshot.hasData) {
          for(var doc in snapshot.data!.docs) {
             final data = doc.data() as Map<String, dynamic>;
             final amount = (data['amount'] ?? 0).toDouble();
             final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
             if(timestamp != null) {
                 final diff = DateTime(now.year, now.month, now.day).difference(DateTime(timestamp.year, timestamp.month, timestamp.day)).inDays;
                 if (diff >= 0 && diff < 30) {
                     int index = 29 - diff; // 0 is 30 days ago, 29 is today
                     dailyIncome[index] = (dailyIncome[index] ?? 0) + amount;
                     total30Days += amount;
                     if (dailyIncome[index]! > maxDaily) {
                       maxDaily = dailyIncome[index]!;
                     }
                 }
             }
          }
        }
        
        if (maxDaily == 0) maxDaily = 20;

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
              Text(AppLocalizations.tr('transactions_30_days'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Text(formatter.format(total30Days), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              SizedBox(
                height: 100,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxDaily * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            const style = TextStyle(color: Colors.grey, fontSize: 10);
                            Widget text = const Text('', style: style);
                            int index = value.toInt();
                            if (index == 0 || index == 7 || index == 14 || index == 21 || index == 29) {
                              DateTime date = thirtyDaysAgo.add(Duration(days: index));
                              text = Text('${date.day} ${DateFormat('MMM', 'id_ID').format(date)}', style: style);
                            }
                            return SideTitleWidget(meta: meta, space: 4, child: text);
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(30, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [BarChartRodData(toY: dailyIncome[i]!, color: Colors.indigoAccent, width: 4, borderRadius: BorderRadius.circular(4))],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildAktivitasTerbaru(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Query query = FirebaseFirestore.instance.collection('activities').orderBy('timestamp', descending: true).limit(3);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.tr('recent_activities'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          stream: query.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                children: snapshot.data!.docs.map((doc) {
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
