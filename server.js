const express = require('express');
const midtransClient = require('midtrans-client');
const cors = require('cors');
const admin = require('firebase-admin');
const multer = require('multer');
const path = require('path');

// Inisialisasi Firebase
const serviceAccount = require('./firebase-key.json');
admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

console.log("🚀 SERVER START...");

const app = express();
app.use(express.json());
app.use(cors());

// Ekspos folder uploads agar file gambar bisa diakses dari aplikasi
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Konfigurasi Multer untuk penyimpanan gambar
const logoStorage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname.replace(/\s+/g, '-'));
    }
});
const logoUpload = multer({ storage: logoStorage });

// Endpoint upload gambar toko
app.post('/upload-logo', logoUpload.single('logo'), (req, res) => {
    if (!req.file) {
        return res.status(400).json({ success: false, message: 'Tidak ada file yang diunggah' });
    }
    
    // Ganti dengan IP VPS yang sebenarnya saat deploy
    const serverUrl = 'http://103.150.226.111:3000';
    const fileUrl = `${serverUrl}/uploads/${req.file.filename}`;
    
    res.json({ success: true, url: fileUrl });
});

// Midtrans config
const snap = new midtransClient.Snap({
    isProduction: false,
    serverKey: 'Mid-server-J-qO' + 'tKtk4PFJqZrS2LZs-bHI',
    clientKey: 'Mid-client-IT' + 'BiAY2rnRoo79J8'
});

// ==========================================
// VARIABLE STATE & ANTRIAN PERINTAH ESP32
// ==========================================
let commandQueue = []; // Menyimpan perintah yang belum di-ACK oleh ESP32
let commandIdCounter = 1; // FIX: Mulai dari 1 agar tidak overflow tipe data 'int' di ESP32 (maks 2.14 miliar)

// Map untuk menyimpan status sinkronisasi Firebase terakhir
// Agar kita tahu kapan status berubah dari Idle -> Active atau sebaliknya
let lastMachineStates = {};

// Fungsi untuk mendeteksi perubahan di Firebase secara real-time
db.collection('machines').onSnapshot(snapshot => {
    snapshot.docChanges().forEach(change => {
        const doc = change.doc;
        const data = doc.data();
        const machineId = doc.id;

        // Pemetaan berdasarkan nama mesin
        let espMachineId = 0;
        const mName = (data.name || "").toLowerCase();
        
        if (mName.includes('washer 1')) espMachineId = 1;
        else if (mName.includes('dryer 1')) espMachineId = 2;
        else if (mName.includes('washer 2')) espMachineId = 3;
        else if (mName.includes('dryer 2')) espMachineId = 4;
        else if (data.type === 'Washer') espMachineId = 1; // Fallback
        else if (data.type === 'Dryer') espMachineId = 2; // Fallback

        if (espMachineId === 0) return; // Abaikan jika tipe tidak diketahui

        if (change.type === 'added' || change.type === 'modified') {
            const currentStatus = data.status; // 'Active' atau 'Idle'

            // Jika ada perubahan status dari sebelumnya
            if (lastMachineStates[machineId] !== currentStatus) {
                console.log(`[FIREBASE] Perubahan terdeteksi: Mesin ${data.name} menjadi ${currentStatus}`);

                // Tambahkan perintah ke antrian ESP32
                commandQueue.push({
                    command_id: commandIdCounter++,
                    machine_id: espMachineId,
                    command: currentStatus === 'Active' ? 'START' : 'STOP',
                    firestore_doc_id: machineId
                });

                lastMachineStates[machineId] = currentStatus;
            }
        }
    });
});

// ==========================================
// ENDPOINT STANDAR
// ==========================================
app.get('/', (req, res) => {
    res.send("Server hidup dan terkoneksi dengan Firebase ✅");
});

app.post('/pay', async (req, res) => {
    try {
        const { price, store_id, package_name, tokens, valid_days } = req.body;
        console.log("💰 Request masuk untuk Top Up:", package_name, price);

        const orderId = 'ORDER-' + Date.now();

        const parameter = {
            transaction_details: {
                order_id: orderId,
                gross_amount: price,
            },
            customer_details: {
                first_name: store_id, // Simpan info toko
            },
            enabled_payments: [
                "gopay",
                "other_qris",
                "shopeepay"
            ]
        };
        const transaction = await snap.createTransaction(parameter);

        // Simpan request ke Firebase sebagai Pending dengan ID orderId
        await db.collection('token_requests').doc(orderId).set({
            store_id: store_id,
            package_name: package_name,
            tokens: tokens,
            valid_days: valid_days || 0,
            price: price,
            method: 'Midtrans',
            status: 'Pending',
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        res.json({
            token: transaction.token,
            redirect_url: transaction.redirect_url
        });
    } catch (err) {
        console.log("❌ ERROR:", err);
        res.status(500).json({ error: err.message });
    }
});

// ==========================================
// MIDTRANS API UNTUK MENYALAKAN MESIN
// ==========================================
app.post('/pay-machine', async (req, res) => {
    try {
        const { price, store_id, machine_id, machine_name, machine_type, timer_enabled, duration_minutes, batch_id } = req.body;
        console.log("💰 Request masuk untuk Sewa Mesin:", machine_name, price);

        const orderId = 'MAC-' + Date.now();

        const parameter = {
            transaction_details: {
                order_id: orderId,
                gross_amount: price,
            },
            customer_details: {
                first_name: store_id, 
            },
            enabled_payments: [
                "gopay",
                "other_qris",
                "shopeepay"
            ]
        };
        const transaction = await snap.createTransaction(parameter);

        // Simpan request
        await db.collection('machine_requests').doc(orderId).set({
            store_id: store_id,
            machine_id: machine_id,
            machine_name: machine_name,
            machine_type: machine_type,
            timer_enabled: timer_enabled,
            duration_minutes: duration_minutes || 0,
            batch_id: batch_id,
            price: price,
            method: 'Midtrans',
            status: 'Pending',
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        res.json({
            token: transaction.token,
            redirect_url: transaction.redirect_url
        });
    } catch (err) {
        console.log("❌ ERROR:", err);
        res.status(500).json({ error: err.message });
    }
});


// ==========================================
// UPLOAD BUKTI TRANSFER MANUAL
// ==========================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'proof-' + uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: storage });

app.post('/upload-proof', upload.single('proof'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'Tidak ada file yang diunggah' });
        }
        // Mengembalikan relative path file yang berhasil disimpan
        const fileUrl = `/uploads/${req.file.filename}`;
        console.log("📸 Bukti transfer diterima:", fileUrl);
        res.json({ success: true, url: fileUrl });
    } catch (e) {
        console.error("Upload Error:", e);
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// MIDTRANS WEBHOOK
// ==========================================
app.post('/midtrans-webhook', async (req, res) => {
    try {
        const statusResponse = await snap.transaction.notification(req.body);
        let orderId = statusResponse.order_id;
        let transactionStatus = statusResponse.transaction_status;
        let fraudStatus = statusResponse.fraud_status;

        console.log(`[WEBHOOK] Order ID: ${orderId}, Status: ${transactionStatus}, Fraud: ${fraudStatus}`);

        if (transactionStatus == 'capture' || transactionStatus == 'settlement') {
            if (fraudStatus == 'challenge') {
                // Abaikan jika challenge (bisa dibuat manual review)
            } else if (fraudStatus == 'accept' || !fraudStatus) {
                // Pembayaran Sukses
                if (orderId.startsWith('MAC-')) {
                    // ALUR PEMBAYARAN MESIN
                    const docRef = db.collection('machine_requests').doc(orderId);
                    const docSnap = await docRef.get();
                    if (docSnap.exists) {
                        const data = docSnap.data();
                        if (data.status === 'Pending') {
                            await docRef.update({ status: 'Approved' });
                            
                            // 1. Potong token dari batchId
                            if (data.batch_id) {
                                const batchRef = db.collection('stores').doc(data.store_id).collection('token_batches').doc(data.batch_id);
                                const batchDoc = await batchRef.get();
                                if (batchDoc.exists && batchDoc.data().remaining_tokens > 0) {
                                    await batchRef.update({
                                        remaining_tokens: admin.firestore.FieldValue.increment(-1)
                                    });
                                }
                            }
                            
                            // 2. Aktifkan mesin
                            await db.collection('machines').doc(data.machine_id).update({
                                status: 'Active',
                                timer_enabled: data.timer_enabled,
                                duration_minutes: data.duration_minutes,
                                start_time: admin.firestore.FieldValue.serverTimestamp(),
                                payment_method: 'QRIS',
                            });

                            // 3. Catat transaksi
                            await db.collection('transactions').add({
                                store_id: data.store_id,
                                machine_id: data.machine_id,
                                machine_name: data.machine_name,
                                machine_type: data.machine_type,
                                timer_enabled: data.timer_enabled,
                                duration_minutes: data.duration_minutes,
                                payment_method: 'QRIS Midtrans',
                                amount: data.price || 0,
                                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                                status: 'Completed',
                            });

                            // 4. Catat Log Aktivitas
                            await db.collection('stores').doc(data.store_id).collection('activities').add({
                                action: `Memulai mesin ${data.machine_name} (${data.timer_enabled ? data.duration_minutes + ' Menit' : 'Tanpa Timer'}) dengan pembayaran QRIS Midtrans`,
                                timestamp: admin.firestore.FieldValue.serverTimestamp()
                            });

                            console.log(`✅ Mesin ${data.machine_id} berhasil dinyalakan via Midtrans`);
                        }
                    }
                } else {
                    // ALUR PEMBELIAN TOKEN (ORDER-...)
                    const docRef = db.collection('token_requests').doc(orderId);
                    const docSnap = await docRef.get();

                    if (docSnap.exists) {
                        const data = docSnap.data();
                        if (data.status === 'Pending') {
                            // Approve request
                            await docRef.update({ status: 'Approved' });
                            // Tambah batch token ke toko
                            const validDays = data.valid_days || 0;
                            
                            let expiredAt = null;
                            if (validDays > 0) {
                                const expirationDate = new Date();
                                expirationDate.setDate(expirationDate.getDate() + validDays);
                                expiredAt = admin.firestore.Timestamp.fromDate(expirationDate);
                            }
                            
                            await db.collection('stores').doc(data.store_id).collection('token_batches').add({
                                package_name: data.package_name || 'Midtrans Package',
                                original_tokens: data.tokens,
                                remaining_tokens: data.tokens,
                                expired_at: expiredAt,
                                purchased_at: admin.firestore.FieldValue.serverTimestamp()
                            });
                            console.log(`✅ Token Batch berhasil ditambahkan ke toko ${data.store_id}`);
                        }
                    }
                }
            }
        } else if (transactionStatus == 'cancel' || transactionStatus == 'deny' || transactionStatus == 'expire') {
            await db.collection('token_requests').doc(orderId).update({ status: 'Failed' });
        }

        res.status(200).json({ status: "ok" });
    } catch (e) {
        console.error("Webhook Error:", e);
        res.status(500).json({ error: e.message });
    }
});

// ==========================================
// ENDPOINT ESP32 API
// ==========================================

// 1. ESP32 Meminta Perintah Baru
app.get('/api/esp32/commands', (req, res) => {
    const deviceId = req.query.device_id;
    
    // Tentukan mesin mana saja yang dikontrol oleh ESP32 yang sedang me-request
    let validMachineIds = [];
    if (deviceId === 'esp32_001') {
        validMachineIds = [1, 2]; // Washer 1, Dryer 1
    } else if (deviceId === 'esp32_002') {
        validMachineIds = [3, 4]; // Washer 2, Dryer 2
    }

    // Filter antrian: hanya kirim perintah yang sesuai dengan mesin ESP32 ini
    // (Jika deviceId tidak dikenali atau kosong, filteredCommands akan kosong)
    const filteredCommands = commandQueue.filter(c => validMachineIds.includes(c.machine_id));

    res.json({
        commands: filteredCommands.map(c => ({
            command_id: c.command_id,
            machine_id: c.machine_id,
            command: c.command
        }))
    });
});

// 2. ESP32 Konfirmasi Perintah Berhasil
app.post('/api/esp32/command/ack', async (req, res) => {
    const { command_id, machine_id, success } = req.body;
    console.log(`[ESP32 ACK] Command ${command_id} untuk mesin ${machine_id} -> ${success ? 'BERHASIL' : 'GAGAL'}`);

    if (success) {
        // Hapus perintah dari antrian
        commandQueue = commandQueue.filter(c => c.command_id !== command_id);
    }

    res.json({ success: true });
});

// 3. ESP32 Mengirim Data Telemetri (Arus Listrik dll)
app.post('/api/esp32/data', async (req, res) => {
    const data = req.body;
    // console.log(`[ESP32 DATA] Diterima dari ${data.device_id}`);

    // Fungsi helper untuk mencari doc ID Firebase berdasarkan espMachineId
    const getDocIdByEspId = async (espId) => {
        let targetName = "";
        if (espId === 1) targetName = 'washer 1';
        else if (espId === 2) targetName = 'dryer 1';
        else if (espId === 3) targetName = 'washer 2';
        else if (espId === 4) targetName = 'dryer 2';
        
        if (targetName) {
            const snapshot = await db.collection('machines').get();
            let foundId = null;
            snapshot.forEach(doc => {
                if (doc.data().name && doc.data().name.toLowerCase().includes(targetName)) {
                    foundId = doc.id;
                }
            });
            if (foundId) return foundId;
        }

        const type = (espId === 1 || espId === 3) ? 'Washer' : 'Dryer';
        const snapshot = await db.collection('machines').where('type', '==', type).limit(1).get();
        if (!snapshot.empty) return snapshot.docs[0].id;
        return null;
    };

    try {
        // Update data untuk Channel 1
        if (data.channel1 && data.channel1.machine_id) {
            const docId = await getDocIdByEspId(data.channel1.machine_id);
            if (docId) {
                await db.collection('machines').doc(docId).update({
                    current_ampere: data.channel1.current,
                    relay_status: data.channel1.relay_status,
                    last_updated: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }

        // Update data untuk Channel 2
        if (data.channel2 && data.channel2.machine_id) {
            const docId = await getDocIdByEspId(data.channel2.machine_id);
            if (docId) {
                await db.collection('machines').doc(docId).update({
                    current_ampere: data.channel2.current,
                    relay_status: data.channel2.relay_status,
                    last_updated: admin.firestore.FieldValue.serverTimestamp()
                });
            }
        }

        res.json({
            success: true,
            commands_pending: commandQueue.length
        });

    } catch (error) {
        console.error("[FIREBASE UPDATE ERROR]", error);
        res.status(500).json({ success: false, error: error.message });
    }
});

// ==========================================
// START SERVER
// ==========================================
app.listen(3000, '0.0.0.0', () => {
    // 0.0.0.0 memastikan server bisa diakses dari ESP32 (via IP LAN)
    console.log("🔥 Server jalan di http://0.0.0.0:3000");
});