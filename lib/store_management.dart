import 'package:aplikasilaundry/custom_snackbar.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aplikasilaundry/activity_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'store_detail.dart';

class StoreManagementPage extends StatefulWidget {
  final String currentRole;

  const StoreManagementPage({super.key, required this.currentRole});

  @override
  State<StoreManagementPage> createState() => _StoreManagementPageState();
}

class _StoreManagementPageState extends State<StoreManagementPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  void _showAddStoreDialog({DocumentSnapshot? existingStore}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StoreFormDialog(existingStore: existingStore, currentRole: widget.currentRole),
    );
  }

  void _deleteStore(String storeId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Store"),
        content: const Text("Are you sure you want to delete this store? All associated data might be affected."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // Hapus semua data yang berhubungan dengan toko ini terlebih dahulu
              try {
                final batch = FirebaseFirestore.instance.batch();
                
                // Hapus mesin
                final machines = await FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: storeId).get();
                for (var doc in machines.docs) { batch.delete(doc.reference); }
                
                // Hapus pelanggan
                final pelanggan = await FirebaseFirestore.instance.collection('pelanggan').where('store_id', isEqualTo: storeId).get();
                for (var doc in pelanggan.docs) { batch.delete(doc.reference); }
                
                // Hapus cashier
                final cashiers = await FirebaseFirestore.instance.collection('users').where('store_id', isEqualTo: storeId).get();
                for (var doc in cashiers.docs) { batch.delete(doc.reference); }
                
                // Hapus tokonya
                batch.delete(FirebaseFirestore.instance.collection('stores').doc(storeId));
                
                await batch.commit();
                
                await ActivityService.logActivity(storeId: storeId, action: "Menghapus toko beserta seluruh isinya");
                
                if (mounted) {
                  Navigator.pop(context);
                  CustomSnackbar.show(context, 
                    const SnackBar(content: Text('Store dan seluruh data terkait berhasil dihapus'), backgroundColor: Colors.red),
                  );
                }
              } catch (e) {
                if (mounted) {
                  CustomSnackbar.show(context, 
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F3460);

    Query storeQuery = FirebaseFirestore.instance.collection('stores');
    
    // Paksa filter hanya toko miliknya sendiri jika bukan Superadmin/Admin
    if (widget.currentRole != 'Superadmin' && widget.currentRole != 'Admin') {
      storeQuery = storeQuery.where('owner_email', isEqualTo: currentUser?.email);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 0,
        title: Text("Store Management", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: storeQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("Belum ada toko yang terdaftar", style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          final stores = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final doc = stores[index];
              final data = doc.data() as Map<String, dynamic>;

              final logoUrl = data['logo_url']?.toString();
              final openTime = data['open_time']?.toString() ?? '08:00';
              final closeTime = data['close_time']?.toString() ?? '22:00';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoreDetailPage(
                            storeId: doc.id,
                            storeName: data['name'],
                            currentRole: widget.currentRole,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              image: logoUrl != null && logoUrl.isNotEmpty
                                ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                                : null,
                            ),
                            child: logoUrl == null || logoUrl.isEmpty
                                ? Icon(Icons.storefront, color: primaryColor, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['name']?.toString() ?? 'Unnamed Store',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                ),
                                if (widget.currentRole == 'Superadmin' || widget.currentRole == 'Admin') ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "👤 Pemilik: ${data['owner_email'] ?? '-'}",
                                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(data['phone']?.toString() ?? '-', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text("$openTime - $closeTime", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.grey),
                            color: cardColor,
                            onSelected: (value) {
                              if (value == 'edit') _showAddStoreDialog(existingStore: doc);
                              if (value == 'delete') _deleteStore(doc.id);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(value: 'edit', child: Text("Edit", style: TextStyle(color: textColor))),
                              const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStoreDialog(),
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_business, color: Colors.white),
        label: const Text("Add Store", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class StoreFormDialog extends StatefulWidget {
  final DocumentSnapshot? existingStore;
  final String currentRole;

  const StoreFormDialog({super.key, this.existingStore, required this.currentRole});

  @override
  State<StoreFormDialog> createState() => _StoreFormDialogState();
}

class _StoreFormDialogState extends State<StoreFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;
  
  // Form values
  late String _name;
  late String _address;
  late String _phone;
  late String _email;
  late String _priceWasher;
  late String _priceDryer;
  late String _bankName;
  late String _bankAccount;
  late String _ownerEmail;
  
  TimeOfDay _openTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 22, minute: 0);
  
  XFile? _imageFile;
  String? _existingLogoUrl;
  
  String _countryCode = '+62';
  final List<String> _bankList = ['BCA', 'Mandiri', 'BNI', 'BRI', 'BSI', 'CIMB Niaga', 'Permata', 'Danamon'];
  
  List<Map<String, String>> _ownerList = [];

  @override
  void initState() {
    super.initState();
    final data = widget.existingStore?.data() as Map<String, dynamic>?;
    
    _name = data?['name'] ?? '';
    _address = data?['address'] ?? '';
    
    String rawPhone = data?['phone'] ?? '';
    if (rawPhone.startsWith('+62')) {
      _countryCode = '+62';
      _phone = rawPhone.substring(3);
    } else if (rawPhone.startsWith('0')) {
      _phone = rawPhone.substring(1);
    } else {
      _phone = rawPhone;
    }

    _email = data?['store_email'] ?? '';
    _priceWasher = data?['price_washer']?.toString() ?? '';
    _priceDryer = data?['price_dryer']?.toString() ?? '';
    
    _bankName = data?['bank_name'] ?? '';
    if (!_bankList.contains(_bankName)) {
      _bankName = _bankList.isNotEmpty ? _bankList.first : '';
    }
    
    _bankAccount = data?['bank_account'] ?? '';
    _ownerEmail = data?['owner_email'] ?? FirebaseAuth.instance.currentUser?.email ?? '';
    _existingLogoUrl = data?['logo_url'];

    if (data != null && data['open_time'] != null) {
      final parts = data['open_time'].toString().split(':');
      if (parts.length == 2) {
        _openTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    if (data != null && data['close_time'] != null) {
      final parts = data['close_time'].toString().split(':');
      if (parts.length == 2) {
        _closeTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    
    if (widget.currentRole == 'Superadmin' || widget.currentRole == 'Admin') {
      _fetchOwners();
    }
  }

  Future<void> _fetchOwners() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'Owner').get();
      if (mounted) {
        setState(() {
          _ownerList = snap.docs.map((d) {
            final data = d.data();
            return {
              'email': data['email']?.toString() ?? '',
              'name': data['name']?.toString() ?? data['email']?.toString() ?? '',
            };
          }).toList();
          
          if (_ownerEmail.isNotEmpty && !_ownerList.any((o) => o['email'] == _ownerEmail)) {
            _ownerList.add({'email': _ownerEmail, 'name': _ownerEmail});
          }
        });
      }
    } catch (e) {
      print("Error fetching owners: $e");
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
    }
  }

  Future<void> _pickTime(bool isOpenTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpenTime ? _openTime : _closeTime,
    );
    if (picked != null) {
      setState(() {
        if (isOpenTime) _openTime = picked;
        else _closeTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  void _confirmAndSave() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi"),
        content: const Text("Pastikan semua data sudah benar sebelum menyimpan.."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cek Kembali"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              _saveStore(); // Proses save
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStore() async {
    setState(() => _isLoading = true);
    
    try {
      String logoUrl = _existingLogoUrl ?? '';

      // Coba upload foto jika ada
      if (_imageFile != null) {
        try {
          final uri = Uri.parse('http://103.150.226.111:3000/upload-logo');
          final request = http.MultipartRequest('POST', uri);
          
          if (kIsWeb) {
            final bytes = await _imageFile!.readAsBytes();
            request.files.add(http.MultipartFile.fromBytes('logo', bytes, filename: _imageFile!.name));
          } else {
            request.files.add(await http.MultipartFile.fromPath('logo', _imageFile!.path));
          }
          
          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode == 200) {
            final resData = jsonDecode(response.body);
            if (resData['success'] == true) {
              logoUrl = resData['url'];
            }
          } else {
            print("Failed to upload: ${response.body}");
          }
        } catch (e) {
          print("Error uploading image: $e");
          // Lanjutkan tanpa upload image jika gagal
        }
      }

      final storeData = {
        'name': _name,
        'address': _address,
        'phone': '$_countryCode$_phone',
        'store_email': _email,
        'price_washer': int.tryParse(_priceWasher) ?? 0,
        'price_dryer': int.tryParse(_priceDryer) ?? 0,
        'bank_name': _bankName,
        'bank_account': _bankAccount,
        'open_time': _formatTime(_openTime),
        'close_time': _formatTime(_closeTime),
        'logo_url': logoUrl,
        'owner_email': _ownerEmail.isNotEmpty ? _ownerEmail : (FirebaseAuth.instance.currentUser?.email ?? ''),
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (widget.existingStore != null) {
        final storeRef = FirebaseFirestore.instance.collection('stores').doc(widget.existingStore!.id);
        await storeRef.update(storeData);
        
        // Update all machines prices for this store
        final machinesSnap = await FirebaseFirestore.instance.collection('machines').where('store_id', isEqualTo: widget.existingStore!.id).get();
        if (machinesSnap.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          int washerPrice = int.tryParse(_priceWasher) ?? 0;
          int dryerPrice = int.tryParse(_priceDryer) ?? 0;
          for (var doc in machinesSnap.docs) {
            final mData = doc.data();
            if (mData['type'] == 'Washer') {
              batch.update(doc.reference, {'price': washerPrice});
            } else if (mData['type'] == 'Dryer') {
              batch.update(doc.reference, {'price': dryerPrice});
            }
          }
          await batch.commit();
        }

        await ActivityService.logActivity(
          storeId: widget.existingStore!.id,
          action: "Mengubah profil toko ($_name)",
        );
      } else {
        storeData['created_at'] = FieldValue.serverTimestamp();
        final docRef = await FirebaseFirestore.instance.collection('stores').add(storeData);
        await ActivityService.logActivity(
          storeId: docRef.id,
          action: "Mendaftarkan toko baru ($_name)",
        );
      }

      if (mounted) {
        Navigator.pop(context); // Tutup bottom sheet
        CustomSnackbar.show(context, 
          SnackBar(content: Text(widget.existingStore != null ? 'Toko diperbarui!' : 'Toko ditambahkan!'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(context, 
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: kIsWeb ? FontWeight.bold : FontWeight.w800, color: color),
      ),
    );
  }

  Widget _buildTextField(String label, String initial, String hint, Function(String?) onSaved, {TextInputType type = TextInputType.text, int maxLines = 1, String? prefixText, required Color fillColor, required Color textColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initial,
          keyboardType: type,
          maxLines: maxLines,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            prefixText: prefixText,
            prefixStyle: TextStyle(color: textColor),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
          onSaved: (v) => onSaved(v),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final fillColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : Colors.grey[200]!;
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F3460);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Header Sticky
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingStore != null ? "Edit Toko" : "Buat Toko Baru",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Form Scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("1. Identitas Toko", color: primaryColor),
                    
                    // Upload Logo
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: fillColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 2, style: BorderStyle.solid),
                          ),
                          child: _imageFile != null
                              ? (kIsWeb ? Image.network(_imageFile!.path, fit: BoxFit.cover) : Image.file(File(_imageFile!.path), fit: BoxFit.cover))
                              : (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty
                                  ? Image.network(_existingLogoUrl!, fit: BoxFit.cover)
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, color: Color(0xFF94A3B8)),
                                        SizedBox(height: 8),
                                        Text("Logo", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                      ],
                                    )),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField("Nama Toko", _name, "Contoh: Laundry Sumur Batu", (v) => _name = v!.trim(), fillColor: fillColor, textColor: textColor),

                    _buildSectionTitle("2. Informasi Kontak & Pemilik", color: primaryColor),
                    
                    if (widget.currentRole == 'Superadmin' || widget.currentRole == 'Admin')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Kepemilikan Toko (Owner)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _ownerEmail.isNotEmpty ? _ownerEmail : null,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                            borderRadius: BorderRadius.circular(16),
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: fillColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            dropdownColor: fillColor,
                            items: _ownerList.map((owner) {
                              return DropdownMenuItem<String>(
                                value: owner['email'],
                                child: Text("${owner['name']} (${owner['email']})", style: TextStyle(color: textColor), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _ownerEmail = newValue;
                                });
                              }
                            },
                            validator: (v) => v == null || v.isEmpty ? "Wajib memilih Owner" : null,
                            onSaved: (v) {
                              if (v != null) _ownerEmail = v;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                      
                    _buildTextField("Alamat Toko", _address, "Alamat lengkap...", (v) => _address = v!.trim(), maxLines: 2, fillColor: fillColor, textColor: textColor),
                    
                    // Custom WhatsApp Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("WhatsApp", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: fillColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _countryCode,
                                  dropdownColor: fillColor,
                                  borderRadius: BorderRadius.circular(16),
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                                  items: const [
                                    DropdownMenuItem(value: '+62', child: Text("🇮🇩 +62")),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _countryCode = v);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: _phone,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                style: TextStyle(color: textColor),
                                decoration: InputDecoration(
                                  hintText: "812345678",
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                  filled: true,
                                  fillColor: fillColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                                onSaved: (v) => _phone = v!.trim(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                    _buildTextField("Email Toko", _email, "Contoh: admin@laundry.com", (v) => _email = v!.trim(), type: TextInputType.emailAddress, fillColor: fillColor, textColor: textColor),

                    _buildSectionTitle("3. Tarif Dasar (Rp)", color: primaryColor),
                    Row(
                      children: [
                        Expanded(child: _buildTextField("Harga Mesin Cuci", _priceWasher, "0", (v) => _priceWasher = v!.trim(), type: TextInputType.number, prefixText: "Rp ", fillColor: fillColor, textColor: textColor)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTextField("Harga Mesin Pengering", _priceDryer, "0", (v) => _priceDryer = v!.trim(), type: TextInputType.number, prefixText: "Rp ", fillColor: fillColor, textColor: textColor)),
                      ],
                    ),

                    _buildSectionTitle("4. Informasi Pembayaran (Payment Gateway)", color: primaryColor),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Nama Bank", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _bankName,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF3B82F6)),
                                borderRadius: BorderRadius.circular(16),
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: fillColor,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                dropdownColor: fillColor,
                                items: _bankList.map((String bank) {
                                  return DropdownMenuItem<String>(
                                    value: bank,
                                    child: Text(bank, style: TextStyle(color: textColor), overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _bankName = newValue!;
                                  });
                                },
                                onSaved: (v) => _bankName = v!,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Nomor Rekening", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: _bankAccount,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: "Contoh: 1234567890",
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                filled: true,
                                fillColor: fillColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                              onSaved: (v) => _bankAccount = v!.trim(),
                            ),
                            const SizedBox(height: 16),
                          ]
                        )),
                      ],
                    ),

                    _buildSectionTitle("5. Jam Operasional", color: primaryColor),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(true),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Buka", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Text(_formatTime(_openTime), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _pickTime(false),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tutup", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Text(_formatTime(_closeTime), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),

          // Footer Sticky (Button)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isLoading ? null : _confirmAndSave,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Simpan Data Toko", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

