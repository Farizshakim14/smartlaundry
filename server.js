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

// Fungsi untuk mengirim Push Notification via FCM
async function sendPushNotification(storeId, title, body) {
    try {
        const usersSnap = await db.collection('users').get();
        let tokens = [];
        usersSnap.forEach(doc => {
            const data = doc.data();
            // Kirim ke token FCM jika user adalah Owner, Superadmin, atau petugas di toko terkait
            if (data.fcm_token) {
                if (data.role === 'Superadmin' || data.role === 'Owner' || data.store_id === storeId) {
                    tokens.push(data.fcm_token);
                }
            }
        });

        if (tokens.length > 0) {
            // Hapus duplikat
            tokens = [...new Set(tokens)];
            const message = {
                notification: { title: title, body: body },
                tokens: tokens
            };
            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`[FCM] Berhasil mengirim ${response.successCount} notifikasi Push.`);
        }
    } catch (error) {
        console.error('[FCM] Error sending push notification:', error);
    }
}

// Listener untuk otomatis mengirim Push Notification saat ada aktivitas baru
const startupTime = Date.now();
db.collection('activities').onSnapshot(snapshot => {
    snapshot.docChanges().forEach(change => {
        if (change.type === 'added') {
            const data = change.doc.data();
            // Hanya kirim notifikasi untuk aktivitas yang baru ditambahkan setelah server menyala
            if (data.timestamp && data.timestamp.toMillis() > startupTime) {
                const action = data.action || 'Aktivitas baru';
                const storeId = data.store_id;
                const userName = data.user_name || 'Sistem';
                sendPushNotification(storeId, `Laundry: ${userName}`, action);
            }
        }
    });
});

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

const coreApi = new midtransClient.CoreApi({
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
                    duration_minutes: data.duration_minutes || 0,
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

// Proxy untuk mengambil gambar QRIS dari Midtrans agar tidak terkena CORS di Flutter Web
app.get('/proxy-qr', async (req, res) => {
    try {
        const qrUrl = req.query.url;
        if (!qrUrl) return res.status(400).send('No URL provided');
        
        const response = await fetch(qrUrl);
        if (!response.ok) throw new Error(`HTTP Error ${response.status}`);
        
        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);
        
        // Teruskan header content-type dari Midtrans (biasanya image/png)
        res.setHeader('Content-Type', response.headers.get('content-type') || 'image/png');
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.send(buffer);
    } catch (e) {
        console.error("Proxy QR Error:", e);
        res.status(500).send(e.message);
    }
});

app.post('/pay', async (req, res) => {
    try {
        const { price, store_id, package_name, tokens, valid_days } = req.body;
        console.log("💰 Request masuk untuk Top Up:", package_name, price);

        const orderId = 'ORDER-' + Date.now();

        const parameter = {
            payment_type: 'qris',
            transaction_details: {
                order_id: orderId,
                gross_amount: price,
            },
            customer_details: {
                first_name: store_id, // Simpan info toko
            }
        };
        const transaction = await coreApi.charge(parameter);

        let qrUrl = null;
        if (transaction.actions && transaction.actions.length > 0) {
            const action = transaction.actions.find(a => a.name === 'generate-qr-code');
            if (action) qrUrl = action.url;
        }

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
            token: transaction.transaction_id,
            qr_url: qrUrl,
            order_id: orderId
        });
    } catch (err) {
        console.log("❌ ERROR:", err);
        res.status(500).json({ error: err.message });
    }
});

// ==========================================
// API PEMBAYARAN SERVICE (QUEUE SYSTEM)
// ==========================================
// ==========================================
// API HAPUS USER (FIREBASE AUTHENTICATION)
// ==========================================
app.post('/delete-user', async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) {
            return res.status(400).json({ success: false, message: 'Email tidak diberikan' });
        }

        console.log(`🗑️ Menerima request penghapusan auth untuk email: ${email}`);
        const userRecord = await admin.auth().getUserByEmail(email);
        await admin.auth().deleteUser(userRecord.uid);
        console.log(`✅ User auth ${email} berhasil dihapus.`);

        res.json({ success: true, message: `User ${email} terhapus dari Auth` });
    } catch (err) {
        if (err.code === 'auth/user-not-found') {
            console.log(`⚠️ User ${req.body.email} tidak ditemukan di Auth. Mengabaikan...`);
            return res.json({ success: true, message: 'User tidak ada di Auth, bisa dilanjutkan.' });
        }
        console.log("❌ ERROR menghapus auth:", err);
        res.status(500).json({ success: false, error: err.message });
    }
});

app.post('/pay-service', async (req, res) => {
    try {
        const { price, store_id, customer_name, customer_phone, service_type, batch_id, quantity, wash_quantity, dry_quantity } = req.body;
        console.log("💰 Request masuk untuk Service:", service_type, customer_name, "Qty:", quantity || 1, "Wash:", wash_quantity, "Dry:", dry_quantity);

        const orderId = 'SRV-' + Date.now();

        const parameter = {
            payment_type: 'qris',
            transaction_details: {
                order_id: orderId,
                gross_amount: price,
            },
            customer_details: {
                first_name: customer_name,
                phone: customer_phone,
            }
        };
        const transaction = await coreApi.charge(parameter);

        let qrUrl = null;
        if (transaction.actions && transaction.actions.length > 0) {
            const action = transaction.actions.find(a => a.name === 'generate-qr-code');
            if (action) qrUrl = action.url;
        }

        await db.collection('service_requests').doc(orderId).set({
            store_id: store_id,
            customer_name: customer_name,
            customer_phone: customer_phone,
            service_type: service_type, // 'Wash', 'Dry', 'Combo', 'Custom'
            quantity: quantity || 1,
            wash_quantity: wash_quantity || 0,
            dry_quantity: dry_quantity || 0,
            batch_id: batch_id,
            price: price,
            method: 'Midtrans',
            status: 'Pending Payment',
            created_at: admin.firestore.FieldValue.serverTimestamp(),
        });

        res.json({
            token: transaction.transaction_id,
            qr_url: qrUrl,
            order_id: orderId
        });
    } catch (err) {
        console.log("❌ ERROR:", err);
        res.status(500).json({ error: err.message });
    }
});

// ==========================================
// FUNGSI ASSIGN MACHINE OTOMATIS
// ==========================================
async function assignMachines(storeId) {
    console.log(`[ASSIGNER] Mengecek antrean untuk toko ${storeId}...`);
    try {
        // Ambil semua mesin idle di toko ini
        const machinesSnap = await db.collection('machines').where('store_id', '==', storeId).get();
        const machines = machinesSnap.docs.map(d => ({ id: d.id, ...d.data() }));
        const idleWashers = machines.filter(m => m.type === 'Washer' && m.status === 'Idle');
        const idleDryers = machines.filter(m => m.type === 'Dryer' && m.status === 'Idle');

        // Ambil semua antrean Pending
        const queueSnap = await db.collection('queues')
            .where('store_id', '==', storeId)
            .where('status', '==', 'Pending')
            .orderBy('created_at', 'asc')
            .get();

        for (const qDoc of queueSnap.docs) {
            const queue = qDoc.data();

            // Tentukan mesin apa yang dibutuhkan
            let neededType = null;
            if (queue.service_type === 'Wash' || (queue.service_type === 'Combo' && queue.step === 'Wash')) {
                neededType = 'Washer';
            } else if (queue.service_type === 'Dry' || (queue.service_type === 'Combo' && queue.step === 'Dry')) {
                neededType = 'Dryer';
            }

            if (neededType === 'Washer' && idleWashers.length > 0) {
                const machine = idleWashers.shift(); // Ambil mesin pertama
                await assignToMachine(qDoc.id, machine, queue);
            } else if (neededType === 'Dryer' && idleDryers.length > 0) {
                const machine = idleDryers.shift();
                await assignToMachine(qDoc.id, machine, queue);
            }
        }
    } catch (e) {
        console.error("[ASSIGNER ERROR]", e);
    }
}

async function assignToMachine(queueId, machine, queue) {
    console.log(`✅ Mengalokasikan Mesin ${machine.name} untuk Pelanggan ${queue.customer_name}`);

    // Ubah status mesin menjadi Ready
    await db.collection('machines').doc(machine.id).update({
        status: 'Ready',
        assigned_to: queue.customer_name,
        assigned_queue_id: queueId,
        payment_method: 'QRIS',
        timer_enabled: true,
        duration_minutes: 45 // Default
    });

    // Ubah status antrean menjadi Assigned
    await db.collection('queues').doc(queueId).update({
        status: 'Assigned',
        assigned_machine_id: machine.id,
        assigned_machine_name: machine.name
    });
}

// Timer pengecekan mesin selesai secara berkala (setiap 30 detik)
setInterval(async () => {
    try {
        const activeSnap = await db.collection('machines').where('status', '==', 'Active').where('timer_enabled', '==', true).get();
        for (const doc of activeSnap.docs) {
            const data = doc.data();
            if (data.start_time && data.duration_minutes) {
                const startTimeMs = data.start_time.toDate().getTime();
                const durationMs = data.duration_minutes * 60000;
                if (Date.now() >= startTimeMs + durationMs) {
                    console.log(`⏰ Mesin ${data.name} selesai! Mengubah ke Idle...`);
                    await db.collection('machines').doc(doc.id).update({
                        status: 'Idle',
                        start_time: admin.firestore.FieldValue.delete(),
                        timer_enabled: admin.firestore.FieldValue.delete(),
                        duration_minutes: admin.firestore.FieldValue.delete(),
                        assigned_to: admin.firestore.FieldValue.delete(),
                        assigned_queue_id: admin.firestore.FieldValue.delete()
                    });

                    // Cek jika ini adalah bagian dari Combo
                    if (data.assigned_queue_id) {
                        const qDoc = await db.collection('queues').doc(data.assigned_queue_id).get();
                        if (qDoc.exists) {
                            const qData = qDoc.data();
                            if (qData.service_type === 'Combo' && qData.step === 'Wash') {
                                // Lanjut ke antrean Dryer
                                await db.collection('queues').doc(qDoc.id).update({
                                    step: 'Dry',
                                    status: 'Pending',
                                    assigned_machine_id: null,
                                    assigned_machine_name: null
                                });
                            }
                        }
                    }

                    // Panggil assigner
                    if (data.store_id) assignMachines(data.store_id);
                }
            }
        }
    } catch (e) {
        console.error("Timer check error:", e);
    }
}, 30000);
// ==========================================
// UPLOAD BUKTI TRANSFER MANUAL
// ==========================================
const proofStorage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/');
    },
    filename: function (req, file, cb) {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'proof-' + uniqueSuffix + path.extname(file.originalname));
    }
});
const upload = multer({ storage: proofStorage });

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
    console.log("\n[WEBHOOK RAW] Request masuk dari Midtrans:", req.body.order_id, req.body.transaction_status);
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
                    // ALUR PEMBAYARAN MESIN (LAMA)
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
                } else if (orderId.startsWith('SRV-')) {
                    // ALUR PEMBAYARAN SERVICE BARU (QUEUE)
                    const docRef = db.collection('service_requests').doc(orderId);
                    const docSnap = await docRef.get();

                    if (docSnap.exists) {
                        const data = docSnap.data();
                        if (data.status === 'Pending Payment') {
                            await docRef.update({ status: 'Paid' });

                            const qty = data.quantity || 1;
                            const washQty = data.wash_quantity !== undefined ? data.wash_quantity : (data.service_type === 'Wash' ? qty : (data.service_type === 'Combo' ? qty : 0));
                            const dryQty = data.dry_quantity !== undefined ? data.dry_quantity : (data.service_type === 'Dry' ? qty : (data.service_type === 'Combo' ? qty : 0));

                            // 1. Potong token jika ada
                            if (data.batch_id) {
                                const batchRef = db.collection('stores').doc(data.store_id).collection('token_batches').doc(data.batch_id);
                                const batchDoc = await batchRef.get();
                                if (batchDoc.exists && batchDoc.data().remaining_tokens > 0) {
                                    // Potong token sebanyak total antrean
                                    const deduct = -(washQty + dryQty);
                                    if (deduct < 0) {
                                        await batchRef.update({
                                            remaining_tokens: admin.firestore.FieldValue.increment(deduct)
                                        });
                                    }
                                }
                            }

                            // 2. Buat antrean (Queue) untuk Washer
                            for (let i = 0; i < washQty; i++) {
                                await db.collection('queues').add({
                                    store_id: data.store_id,
                                    customer_name: data.customer_name,
                                    customer_phone: data.customer_phone,
                                    service_type: data.service_type,
                                    step: 'Wash',
                                    status: 'Pending', // Menunggu mesin kosong
                                    created_at: admin.firestore.FieldValue.serverTimestamp()
                                });
                            }

                            // 2. Buat antrean (Queue) untuk Dryer
                            for (let i = 0; i < dryQty; i++) {
                                await db.collection('queues').add({
                                    store_id: data.store_id,
                                    customer_name: data.customer_name,
                                    customer_phone: data.customer_phone,
                                    service_type: data.service_type,
                                    step: 'Dry',
                                    status: 'Pending', // Menunggu mesin kosong
                                    created_at: admin.firestore.FieldValue.serverTimestamp()
                                });
                            }

                            // 3. Catat transaksi (Satu transaksi total untuk riwayat)
                            await db.collection('transactions').add({
                                store_id: data.store_id,
                                customer_name: data.customer_name,
                                service_type: data.service_type === 'Custom' ? `Cuci x${washQty}, Kering x${dryQty}` : data.service_type,
                                payment_method: 'QRIS Midtrans',
                                amount: data.price || 0,
                                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                                status: 'Completed',
                            });

                            console.log(`✅ Pembayaran Service sukses untuk ${data.customer_name}, mengecek ketersediaan mesin...`);

                            // 4. Trigger Assigner
                            assignMachines(data.store_id);
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
            command: c.command,
            duration_minutes: c.duration_minutes
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

    // Cache untuk menghindari query database setiap 2 detik (Menghemat Kuota Firestore)
    if (!global.machineIdCache) global.machineIdCache = {};

    const getDocIdByEspId = async (espId) => {
        if (global.machineIdCache[espId]) return global.machineIdCache[espId];

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
            if (foundId) {
                global.machineIdCache[espId] = foundId;
                return foundId;
            }
        }

        const type = (espId === 1 || espId === 3) ? 'Washer' : 'Dryer';
        const snapshot = await db.collection('machines').where('type', '==', type).limit(1).get();
        if (!snapshot.empty) {
            global.machineIdCache[espId] = snapshot.docs[0].id;
            return snapshot.docs[0].id;
        }
        return null;
    };

    // Helper untuk membatasi frekuensi Write (Update ke Firebase hanya setiap 10 detik atau jika status berubah)
    if (!global.lastMachineUpdate) global.lastMachineUpdate = {};

    const shouldUpdateFirebase = (docId, relayStatus, currentAmpere) => {
        const now = Date.now();
        const last = global.lastMachineUpdate[docId] || { time: 0, relay: null, ampere: 0 };
        
        // Selalu update jika status mesin (ON/OFF) berubah
        if (last.relay !== relayStatus) return true;
        
        // Update jika ampere berubah drastis (>0.5A)
        if (Math.abs(last.ampere - currentAmpere) > 0.5) return true;

        // Selain itu, batasi update maksimal setiap 10 detik sekali (10000 ms)
        if (now - last.time > 10000) return true;

        return false;
    };

    try {
        // Update data untuk Channel 1
        if (data.channel1 && data.channel1.machine_id) {
            const docId = await getDocIdByEspId(data.channel1.machine_id);
            if (docId && shouldUpdateFirebase(docId, data.channel1.relay_status, data.channel1.current)) {
                await db.collection('machines').doc(docId).update({
                    current_ampere: data.channel1.current,
                    relay_status: data.channel1.relay_status,
                    raw_adc: data.channel1.raw_adc,
                    zero_offset: data.channel1.zero_offset,
                    rms_voltage: data.channel1.rms_voltage,
                    calibration_factor: data.channel1.calibration_factor,
                    dryer_remaining_minutes: data.channel1.dryer_remaining_minutes,
                    wifi_ssid: data.wifi_ssid,
                    wifi_rssi: data.wifi_rssi,
                    last_updated: admin.firestore.FieldValue.serverTimestamp()
                });
                global.lastMachineUpdate[docId] = { time: Date.now(), relay: data.channel1.relay_status, ampere: data.channel1.current };
            }
        }

        // Update data untuk Channel 2
        if (data.channel2 && data.channel2.machine_id) {
            const docId = await getDocIdByEspId(data.channel2.machine_id);
            if (docId && shouldUpdateFirebase(docId, data.channel2.relay_status, data.channel2.current)) {
                await db.collection('machines').doc(docId).update({
                    current_ampere: data.channel2.current,
                    relay_status: data.channel2.relay_status,
                    raw_adc: data.channel2.raw_adc,
                    zero_offset: data.channel2.zero_offset,
                    rms_voltage: data.channel2.rms_voltage,
                    calibration_factor: data.channel2.calibration_factor,
                    dryer_remaining_minutes: data.channel2.dryer_remaining_minutes,
                    wifi_ssid: data.wifi_ssid,
                    wifi_rssi: data.wifi_rssi,
                    last_updated: admin.firestore.FieldValue.serverTimestamp()
                });
                global.lastMachineUpdate[docId] = { time: Date.now(), relay: data.channel2.relay_status, ampere: data.channel2.current };
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

// 4. API Untuk Memicu Kalibrasi Nirkabel dari Aplikasi
app.post('/api/esp32/calibrate', async (req, res) => {
    const { machine_id, current_ampere } = req.body;

    if (!machine_id || !current_ampere) {
        return res.status(400).json({ success: false, message: 'Missing machine_id or current_ampere' });
    }

    try {
        // Cari espMachineId berdasarkan firestore machine doc_id
        const docSnap = await db.collection('machines').doc(machine_id).get();
        if (!docSnap.exists) {
            return res.status(404).json({ success: false, message: 'Machine not found' });
        }

        const data = docSnap.data();
        let espMachineId = 0;
        const mName = (data.name || "").toLowerCase();

        if (mName.includes('washer 1')) espMachineId = 1;
        else if (mName.includes('dryer 1')) espMachineId = 2;
        else if (mName.includes('washer 2')) espMachineId = 3;
        else if (mName.includes('dryer 2')) espMachineId = 4;
        else if (data.type === 'Washer') espMachineId = 1;
        else if (data.type === 'Dryer') espMachineId = 2;

        if (espMachineId === 0) {
            return res.status(400).json({ success: false, message: 'Cannot map to ESP machine ID' });
        }

        // duration_minutes digunakan sebagai tempat menaruh angka kalibrasi 
        // Contoh: 5.4A dikali 100 = 540 agar jadi integer
        const kalibrasiVal = Math.round(current_ampere * 100);

        commandQueue.push({
            command_id: commandIdCounter++,
            machine_id: espMachineId,
            command: 'CALIBRATE',
            duration_minutes: kalibrasiVal,
            firestore_doc_id: machine_id
        });

        console.log(`[CALIBRATE] Antrean kalibrasi untuk mesin ${espMachineId} dengan nilai ${current_ampere}A ditambahkan`);
        res.json({ success: true, message: 'Calibration command queued successfully' });
    } catch (error) {
        console.error("[CALIBRATE ERROR]", error);
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