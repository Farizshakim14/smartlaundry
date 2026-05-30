<div align="center">
  <img src="assets/logolaundry.png" alt="Smart Laundry Logo" width="150"/>
  <h1>Smart Laundry Management System</h1>
  <p>Sistem Manajemen Laundry Cerdas berbasis Internet of Things (IoT) dengan integrasi Pembayaran Cashless</p>
</div>

---

## 📖 Tentang Proyek

**Smart Laundry** adalah aplikasi manajemen *laundry* modern berbasis web yang dibangun menggunakan **Flutter Web**. Sistem ini dirancang untuk mendigitalisasi operasional mesin cuci secara *real-time* dengan mengintegrasikan perangkat keras IoT (**ESP32**) dan sistem pembayaran otomatis menggunakan **Midtrans Payment Gateway**. 

Aplikasi ini sangat cocok untuk manajemen *franchise* atau multi-toko karena dilengkapi dengan sistem akses berlapis (*Role-Based Access Control*).

## ✨ Fitur Utama

- 🔐 **Role-Based Access Control (RBAC):** Hak akses spesifik untuk *Superadmin*, *Admin*, *Owner*, dan *Cashier*.
- 🌐 **Multi-Store Management:** Kelola banyak cabang toko *laundry* dari satu dasbor pusat.
- 📡 **IoT Machine Monitoring:** Pantau status mesin cuci dan mesin pengering secara *real-time* (Tersedia / Sedang Berjalan / Selesai) menggunakan modul ESP32.
- 💳 **Cashless & Token System:** Pelanggan dapat membeli token digital menggunakan berbagai metode pembayaran via Midtrans (GoPay, QRIS, Virtual Account, dll).
- 🔔 **Real-Time Notifications:** Dapatkan notifikasi dan log aktivitas secara instan dengan umpan balik suara setiap kali ada aktivitas baru atau mesin yang telah selesai.
- 🎨 **Modern UI/UX:** Desain *dashboard* responsif bergaya SaaS (*Software as a Service*) yang mendukung penuh **Light Mode** dan **Dark Mode**.

## 🛠️ Teknologi yang Digunakan

**Frontend:**
- [Flutter](https://flutter.dev/) (Web)
- Dart

**Backend & Layanan Cloud:**
- [Node.js](https://nodejs.org/) & Express.js
- [Firebase Authentication](https://firebase.google.com/products/auth)
- [Firebase Cloud Firestore](https://firebase.google.com/products/firestore) (Real-time Database)

**Hardware & IoT:**
- ESP32 Microcontroller (C++/Arduino IDE)

**Payment Gateway:**
- [Midtrans](https://midtrans.com/) Snap API

## 🚀 Panduan Instalasi & Konfigurasi

### 1. Prasyarat Sistem
Pastikan Anda telah menginstal perangkat lunak berikut:
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versi terbaru)
- [Node.js](https://nodejs.org/) (versi 16 atau lebih baru)
- Git

### 2. Kloning Repositori
```bash
git clone https://github.com/Farizshakim14/smartlaundry.git
cd smartlaundry
```

### 3. Konfigurasi Backend (Node.js)
1. Buka terminal di dalam *root folder* proyek.
2. Instal dependensi *backend*:
   ```bash
   npm install express cors multer firebase-admin midtrans-client
   ```
3. Tambahkan *file* kredensial Firebase Anda (`firebase-key.json`) ke *root folder*. *(Catatan: File ini diabaikan oleh Git demi keamanan)*.
4. Buat folder `uploads` untuk menyimpan logo toko:
   ```bash
   mkdir uploads
   ```
5. Jalankan server:
   ```bash
   node server.js
   ```

### 4. Konfigurasi Frontend (Flutter)
1. Instal dependensi Flutter:
   ```bash
   flutter pub get
   ```
2. Jalankan aplikasi di *browser* (mode web-server lokal):
   ```bash
   flutter run -d web-server
   ```

## 🔒 Keamanan (Security Notes)
Beberapa *file* penting telah ditambahkan ke `.gitignore` secara otomatis untuk mencegah kebocoran data:
- Kredensial Admin Firebase (`firebase-key.json`)
- Folder dependensi Node (`node_modules/`)
- Folder unggahan gambar (`uploads/`)

Pastikan Anda TIDAK mengunggah kunci rahasia (*Server Key*) Midtrans Anda secara publik. Disarankan untuk menggunakan Environment Variables (`.env`) pada server produksi Anda.

---

<div align="center">
  <br>
  <i>Dibuat untuk memodernisasi manajemen Laundry di Indonesia.</i>
</div>
