const admin = require('firebase-admin');
const serviceAccount = require('./firebase-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRequests() {
  const snapshot = await db.collection('token_requests').orderBy('created_at', 'desc').limit(5).get();
  snapshot.forEach(doc => {
    console.log(doc.id, '=>', doc.data());
  });
}

checkRequests().then(() => process.exit(0)).catch(e => {
  console.error(e);
  process.exit(1);
});
