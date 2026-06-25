import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      // 1. Meminta izin (terutama untuk iOS dan Web)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted notification permission');
      } else {
        print('User declined or has not accepted notification permission');
      }

      // 2. Mendapatkan FCM Token
      String? token;
      
      if (kIsWeb) {
        // Untuk Web, kita butuh VAPID Key. Untuk sementara bisa kosong tapi akan butuh dikonfigurasi di Firebase Console nanti
        // token = await _fcm.getToken(vapidKey: "YOUR_VAPID_KEY");
        token = await _fcm.getToken();
      } else {
        token = await _fcm.getToken();
      }

      print('FCM Token: $token');

      // 3. Simpan token ke Firestore
      await saveTokenToDatabase(token);

      // 4. Update token jika berubah
      _fcm.onTokenRefresh.listen(saveTokenToDatabase);

      // 5. Setup handler saat aplikasi dibuka dari notifikasi (opsional)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        print('Message data: ${message.data}');

        if (message.notification != null) {
          print('Message also contained a notification: ${message.notification}');
          // Di sini Anda bisa memunculkan snackbar/dialog kustom jika mau
        }
      });
      
    } catch (e) {
      print("Error initializing FCM: $e");
    }
  }

  static Future<void> saveTokenToDatabase(String? token) async {
    if (token == null) return;
    
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        final query = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();
        if (query.docs.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(query.docs.first.id).update({
            'fcm_token': token,
            'last_fcm_update': FieldValue.serverTimestamp(),
          });
          print("FCM Token berhasil disimpan ke user ${user.email}");
        }
      } catch (e) {
        print("Gagal menyimpan FCM token: $e");
      }
    }
  }
}
