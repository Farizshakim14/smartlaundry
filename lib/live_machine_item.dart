import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplikasilaundry/localization.dart';

class LiveMachineItem extends StatefulWidget {
  final Map<String, dynamic> data;

  const LiveMachineItem({super.key, required this.data});

  @override
  State<LiveMachineItem> createState() => _LiveMachineItemState();
}

class _LiveMachineItemState extends State<LiveMachineItem> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final data = widget.data;
    final name = data['name']?.toString() ?? AppLocalizations.tr('unknown');
    final rawStatus = data['status']?.toString() ?? 'Idle';
    final type = data['type']?.toString() ?? 'Washer';
    
    final currentAmpere = double.tryParse(data['current_ampere']?.toString() ?? data['current']?.toString() ?? '0') ?? 0.0;
    
    Color color = const Color(0xFFF59E0B); // Idle
    double progress = 0.0;
    String timeLeft = "-";
    String status = rawStatus == 'Idle' ? AppLocalizations.tr('idle') : rawStatus;
    
    if (rawStatus == 'Active') {
      // Smart Status based on Ampere
      if (currentAmpere < 0.5) {
         status = "Menunggu Dinyalakan";
         color = const Color(0xFFF59E0B); // Kuning
      } else {
         status = type == 'Washer' ? AppLocalizations.tr('washing') : AppLocalizations.tr('drying');
         color = type == 'Washer' ? const Color(0xFF2563EB) : const Color(0xFF10B981);
      }
      
      final rawTimer = data['timer_enabled'];
      final timerEnabled = rawTimer == true || rawTimer == 1 || rawTimer == '1' || rawTimer == 'true';
      if (timerEnabled && data['start_time'] != null && data['duration_minutes'] != null) {
         DateTime startTime;
         if (data['start_time'] is Timestamp) {
           startTime = (data['start_time'] as Timestamp).toDate();
         } else if (data['start_time'] is String) {
           startTime = DateTime.tryParse(data['start_time'])?.toLocal() ?? DateTime.now();
         } else if (data['start_time'] is int || data['start_time'] is double) {
           startTime = DateTime.fromMillisecondsSinceEpoch(int.tryParse(data['start_time'].toString()) ?? 0);
         } else {
           startTime = DateTime.now();
         }
         
         final durationMins = int.tryParse(data['duration_minutes'].toString()) ?? 0;
         final endTime = startTime.add(Duration(minutes: durationMins));
         final now = DateTime.now();
         
         if (now.isBefore(endTime)) {
           final diff = endTime.difference(now);
           final totalSecs = durationMins * 60;
           final passedSecs = totalSecs - diff.inSeconds;
           progress = (passedSecs / totalSecs).clamp(0.0, 1.0);
           
           if (type == 'Dryer' && data['dryer_remaining_minutes'] != null) {
               // Gunakan data real dari ESP32 untuk Dryer
               int remMins = int.tryParse(data['dryer_remaining_minutes'].toString()) ?? 0;
               timeLeft = "${remMins}m 0s";
               progress = ((durationMins - remMins) / durationMins).clamp(0.0, 1.0);
           } else {
               final min = diff.inMinutes;
               final sec = diff.inSeconds % 60;
               timeLeft = "${min}m ${sec}s";
           }
         } else {
           progress = 1.0;
           timeLeft = "0m 0s";
         }
      } else {
         progress = 1.0; 
         timeLeft = AppLocalizations.tr('running');
      }
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (rawStatus == 'Active')
                BoxShadow(
                  color: color.withOpacity(_pulseAnimation.value * 0.4),
                  blurRadius: 20 * _pulseAnimation.value,
                  spreadRadius: 2 * _pulseAnimation.value,
                ),
            ],
            border: rawStatus == 'Active'
                ? Border.all(color: color.withOpacity(_pulseAnimation.value * 0.5), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: child,
        );
      },
      child: Row(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress > 0 && progress < 1.0)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  if (progress == 1.0)
                    SizedBox(
                      height: 40,
                      width: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        backgroundColor: color.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  Icon(
                    Icons.local_laundry_service,
                    color: color,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
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
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Daya: ${currentAmpere.toStringAsFixed(2)} A",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppLocalizations.tr('time_left'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeLeft,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
