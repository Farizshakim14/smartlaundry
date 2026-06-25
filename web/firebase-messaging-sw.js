importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: 'AIzaSyCSZ4CEI259wLP7wbAdFFDELWIsRkeoyTg',
    appId: '1:996988566077:web:8666b13eab896c24954854',
    messagingSenderId: '996988566077',
    projectId: 'monitoringlaundry-adba4',
    authDomain: 'monitoringlaundry-adba4.firebaseapp.com',
    databaseURL: 'https://monitoringlaundry-adba4-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'monitoringlaundry-adba4.firebasestorage.app',
    measurementId: 'G-LCM75KHLSC'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
