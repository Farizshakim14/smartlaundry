import 'package:flutter/material.dart';

class GuidePage extends StatelessWidget {
  final String role;
  
  const GuidePage({Key? key, required this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String title = "Panduan Aplikasi";
    List<Widget> content = [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = role.toLowerCase();
    
    if (r == 'owner' || r == 'superadmin' || r == 'admin') {
      title = "Panduan Owner / Admin";
      content = [
        _buildSection("Dashboard", "Lihat ringkasan statistik, total mesin aktif, status token, dan antrean pelanggan secara real-time.", isDark),
        _buildSection("Store Management", "Atur mesin cuci dan pengering Anda. Anda dapat menambah, mengedit, dan menghapus data mesin yang ada di toko Anda.", isDark),
        _buildSection("User Management", "Kelola kasir atau admin yang bertugas di toko Anda. Anda bisa menambahkan staf baru dan menetapkan role mereka.", isDark),
        _buildSection("Mode Pelanggan", "Mode khusus bergaya Kiosk (Self-Service). Dapat diletakkan di tablet kasir agar pelanggan bisa memesan layanan secara mandiri menggunakan QRIS.", isDark),
        _buildSection("Master Pelanggan", "Kelola data pelanggan yang pernah memesan layanan. Anda juga bisa melihat statistik penggunaan mesin (Mesin Cuci & Mesin Pengering) mereka.", isDark),
        _buildSection("Pengaturan", "Ubah profil toko, informasi akun pribadi Anda, dan preferensi aplikasi lainnya.", isDark),
      ];
    } else if (r == 'cashier') {
      title = "Panduan Kasir";
      content = [
        _buildSection("Dashboard", "Pantau antrean mesin mana yang sedang berjalan atau sudah selesai. Anda juga bisa memantau sisa token toko.", isDark),
        _buildSection("Mode Pelanggan", "Gunakan menu ini jika Anda membantu pelanggan untuk memesan langsung di meja kasir. Pembayaran terintegrasi dengan QRIS.", isDark),
        _buildSection("Master Pelanggan", "Lihat dan kelola data pelanggan yang mencuci di toko. Anda dapat melihat sudah berapa kali pelanggan tersebut memakai mesin di toko Anda.", isDark),
        _buildSection("Pengaturan", "Ubah kata sandi dan profil akun Anda.", isDark),
      ];
    } else {
      title = "Panduan Umum";
      content = [
        _buildSection("Mulai", "Silakan tunggu admin atau owner menetapkan tugas dan toko untuk Anda. Setelah ditetapkan, Anda akan bisa mengakses fitur-fitur kasir.", isDark),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            "Halo, $role!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Berikut adalah panduan penggunaan aplikasi sesuai dengan peran Anda:",
            style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ...content,
        ],
      ),
    );
  }

  Widget _buildSection(String title, String description, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
