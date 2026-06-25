const admin = require('firebase-admin');
const serviceAccount = require('./firebase-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function checkRequests() {
  const snapshot = await db.collection('token_requests').get();
  snapshot.forEach(doc => {
    if (doc.id.startsWith('A')) {
      console.log('Found:', doc.id, '=>', doc.data());
    }
  });
  console.log('Done scanning.');
}

checkRequests().then(() => process.exit(0)).catch(e => {
  console.error(e);
  process.exit(1);
});
