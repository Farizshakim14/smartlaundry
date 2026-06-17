import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  static ValueNotifier<String> currentLanguage = ValueNotifier('id');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('language');
    if (savedLang != null) {
      currentLanguage.value = savedLang;
    }
  }

  static Future<void> changeLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    currentLanguage.value = langCode;
  }

  static String tr(String key) {
    return _localizedValues[currentLanguage.value]?[key] ?? _localizedValues['id']?[key] ?? key;
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'id': {
      // General
      'greeting_morning': 'Selamat Pagi',
      'greeting_afternoon': 'Selamat Siang',
      'greeting_evening': 'Selamat Sore',
      'greeting_night': 'Selamat Malam',
      'welcome': 'Selamat Datang',
      'user': 'Pengguna',
      
      // Dashboard Tab
      'home': 'Beranda',
      'machine': 'Mesin',
      'transaction': 'Transaksi',
      'stats': 'Stats',
      'profile': 'Profil',
      'choose_branch': 'Pilih Cabang',
      'branch_not_set': 'Alamat diatur oleh Admin',
      'token_balance': 'Sisa Token',
      'premium_package': 'Paket Premium',
      'token': 'Token',
      'valid_until': 'Berlaku sampai',
      'valid_forever': 'Berlaku selamanya',
      'today_income': 'Pendapatan Hari Ini',
      'from_yesterday': 'Dari kemarin',
      'machine_status': 'Status Mesin',
      'see_all': 'Lihat Semua >',
      'washer_active': 'Washer Aktif',
      'washer_idle': 'Washer Idle',
      'dryer_active': 'Dryer Aktif',
      'dryer_idle': 'Dryer Idle',
      'transactions_30_days': 'Transaksi (30 Hari Terakhir)',
      'recent_activities': 'Aktivitas Terbaru',
      'running_machines': 'Mesin Berjalan',
      'no_activity': 'Belum ada aktivitas.',
      'just_now': 'Baru saja',
      'mins_ago': 'menit lalu',
      'hours_ago': 'jam lalu',
      'days_ago': 'hari lalu',
      
      // Machine Status
      'idle': 'Menunggu',
      'active': 'Aktif',
      'offline': 'Offline',
      'washing': 'Mencuci',
      'drying': 'Mengeringkan',
      'time_left': 'Sisa Waktu',
      'running': 'Berjalan',
      'unknown': 'Tidak Diketahui',
      
      // Bottom Sheet
      'create_transaction': 'Buat Transaksi',
      'wash_only': 'Cuci Saja',
      'dry_only': 'Kering Saja',
      'combo_package': 'Paket Combo',
      'new_customer': 'Pelanggan Baru',
      'add_to_queue': 'Tambah ke Antrean',
      'top_up_token': 'Top Up Token',
      'close': 'Tutup',

      // Settings
      'settings': 'Pengaturan',
      'verification_status': 'Status Verifikasi',
      'email': 'Email',
      'phone_number': 'WhatsApp / Nomor HP',
      'not_set': 'Belum diatur',
      'verify': 'Verifikasi',
      'verified': 'Terverifikasi',
      'account': 'Akun',
      'edit_profile': 'Edit Profile',
      'change_password': 'Ubah Password',
      'application': 'Aplikasi',
      'language': 'Bahasa',
      'indonesian': 'Indonesia',
      'english': 'English',
      'dark_mode': 'Mode Gelap (Dark Mode)',
      
      // Empty State
      'welcome_workspace': 'Selamat datang di Workspace!',
      'no_store_desc': 'Tampaknya belum ada toko yang terdaftar. Mulailah dengan menambahkan toko pertama Anda untuk mengelola mesin, token, dan memantau transaksi.',
      'add_new_store': 'Tambah Toko Baru',
    },
    'en': {
      // General
      'greeting_morning': 'Good Morning',
      'greeting_afternoon': 'Good Afternoon',
      'greeting_evening': 'Good Evening',
      'greeting_night': 'Good Night',
      'welcome': 'Welcome',
      'user': 'User',
      
      // Dashboard Tab
      'home': 'Home',
      'machine': 'Machine',
      'transaction': 'Transaction',
      'stats': 'Stats',
      'profile': 'Profile',
      'choose_branch': 'Choose Branch',
      'branch_not_set': 'Address set by Admin',
      'token_balance': 'Token Balance',
      'premium_package': 'Premium Package',
      'token': 'Tokens',
      'valid_until': 'Valid until',
      'valid_forever': 'Valid forever',
      'today_income': 'Today\'s Income',
      'from_yesterday': 'From yesterday',
      'machine_status': 'Machine Status',
      'see_all': 'See All >',
      'washer_active': 'Active Washer',
      'washer_idle': 'Idle Washer',
      'dryer_active': 'Active Dryer',
      'dryer_idle': 'Idle Dryer',
      'transactions_30_days': 'Transactions (Last 30 Days)',
      'recent_activities': 'Recent Activities',
      'running_machines': 'Running Machines',
      'no_activity': 'No activities yet.',
      'just_now': 'Just now',
      'mins_ago': 'mins ago',
      'hours_ago': 'hours ago',
      'days_ago': 'days ago',
      
      // Machine Status
      'idle': 'Idle',
      'active': 'Active',
      'offline': 'Offline',
      'washing': 'Washing',
      'drying': 'Drying',
      'time_left': 'Time Left',
      'running': 'Running',
      'unknown': 'Unknown',
      
      // Bottom Sheet
      'create_transaction': 'Create Transaction',
      'wash_only': 'Wash Only',
      'dry_only': 'Dry Only',
      'combo_package': 'Combo Package',
      'new_customer': 'New Customer',
      'add_to_queue': 'Add to Queue',
      'top_up_token': 'Top Up Token',
      'close': 'Close',

      // Settings
      'settings': 'Settings',
      'verification_status': 'Verification Status',
      'email': 'Email',
      'phone_number': 'WhatsApp / Phone Number',
      'not_set': 'Not set',
      'verify': 'Verify',
      'verified': 'Verified',
      'account': 'Account',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'application': 'Application',
      'language': 'Language',
      'indonesian': 'Indonesian',
      'english': 'English',
      'dark_mode': 'Dark Mode',
      
      // Empty State
      'welcome_workspace': 'Welcome to Workspace!',
      'no_store_desc': 'It seems there are no registered stores yet. Start by adding your first store to manage machines, tokens, and monitor transactions.',
      'add_new_store': 'Add New Store',
    }
  };
}
