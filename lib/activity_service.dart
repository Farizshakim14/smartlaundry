import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ActivityService {
  static Future<void> logActivity({
    required String action,
    String? storeId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String userName = user.displayName ?? 'Unknown User';
      String role = 'Unknown';
      
      // Attempt to fetch current user's role from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: user.email).limit(1).get();
      if (userDoc.docs.isNotEmpty) {
        final data = userDoc.docs.first.data();
        userName = data['name'] ?? userName;
        role = data['role'] ?? 'Unknown';
        
        // If storeId is not provided, try to use the user's assigned storeId
        if (storeId == null && data['store_id'] != null) {
          storeId = data['store_id'];
        }
      } else if (user.email == 'farizshakim.14@gmail.com') {
        role = 'Superadmin';
      }

      await FirebaseFirestore.instance.collection('activities').add({
        'store_id': storeId ?? 'GLOBAL', // If no store, mark as GLOBAL
        'user_name': userName,
        'user_email': user.email,
        'user_role': role,
        'action': action,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Failed to log activity: $e");
    }
  }
}
