import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Gunakan 10.0.2.2 jika menggunakan Emulator Android
  // Gunakan IP lokal komputer (contoh: 192.168.1.5) jika menggunakan HP fisik
  static const String baseUrl = 'http://103.150.226.111/api'; 

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
  }

  // --- AUTHENTICATION ---
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access_token'] != null) {
        await saveToken(data['access_token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> loginWithGoogle(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/google'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access_token'] != null) {
        await saveToken(data['access_token']);
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(userData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal mendaftar di server backend'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteUser(String email) async {
    final token = await getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/delete'),
        headers: {
          'Content-Type': 'application/json', 
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'User deleted'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal menghapus user di backend'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json', 
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> logout() async {
    final token = await getToken();
    if (token == null) return true;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Content-Type': 'application/json', 
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      await clearToken();
      return response.statusCode == 200;
    } catch (e) {
      await clearToken();
      return false;
    }
  }

  // --- PROFILE ---

  Future<Map<String, dynamic>> updateProfile(String name, String? newEmail) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json', 
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          if (newEmail != null && newEmail.isNotEmpty) 'email': newEmail,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'user': data['user']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal memperbarui profil'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: {
          'Content-Type': 'application/json', 
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Berhasil mengubah password'};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Gagal mengubah password'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // --- MACHINES ---

  Future<List<Map<String, dynamic>>> getMachines({String? storeId}) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      String url = '$baseUrl/machines';
      if (storeId != null) {
        url += '?store_id=$storeId';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> machines = data['machines'] ?? [];
        return machines.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> startMachine(String machineId, bool timerEnabled, int durationMinutes) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/machines/$machineId/start'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'timer_enabled': timerEnabled,
          'duration_minutes': durationMinutes,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to start machine'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> stopMachine(String machineId) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/machines/$machineId/stop'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to stop machine'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addMachine(Map<String, dynamic> machineData) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/machines'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(machineData),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': data['machine']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to add machine'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateMachine(String machineId, Map<String, dynamic> machineData) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/machines/$machineId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(machineData),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['machine']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to update machine'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteMachine(String machineId) async {
    final token = await getToken();
    if (token == null) return false;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/machines/$machineId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- TRANSACTIONS ---

  Future<List<Map<String, dynamic>>> getTransactions({String? storeId}) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      String url = '$baseUrl/transactions';
      if (storeId != null) url += '?store_id=$storeId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> transactions = data['transactions'] ?? [];
        return transactions.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // --- MANUAL TRANSACTIONS ---

  Future<List<Map<String, dynamic>>> getManualTransactions({String? storeId}) async {
    final token = await getToken();
    if (token == null) return [];

    try {
      String url = '$baseUrl/manual-transactions';
      if (storeId != null) url += '?store_id=$storeId';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> transactions = data['transactions'] ?? [];
        return transactions.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addManualTransaction(String storeId, String title, int amount, String type) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/manual-transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'store_id': storeId,
          'title': title,
          'amount': amount,
          'type': type,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) return {'success': true, 'data': data['transaction']};
      return {'success': false, 'message': data['message'] ?? 'Gagal menambahkan'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateManualTransaction(String id, String title, int amount, String type) async {
    final token = await getToken();
    if (token == null) return {'success': false, 'message': 'No token'};

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/manual-transactions/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'amount': amount,
          'type': type,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, 'data': data['transaction']};
      return {'success': false, 'message': data['message'] ?? 'Gagal mengupdate'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteManualTransaction(String id) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/manual-transactions/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
