importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBxkrJl2R49iktFXUYyReSwMd-KKEdJZ8w',
  appId: '1:491619971507:web:e0c77254d82c5304261bc6',
  messagingSenderId: '491619971507',
  projectId: 'naliv-web',
  authDomain: 'naliv-web.firebaseapp.com',
  storageBucket: 'naliv-web.firebasestorage.app',
  measurementId: 'G-GG63GW9EFK',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'Градусы24';
  const options = {
    body: notification.body || 'У вас новое уведомление',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow(self.location.origin));
});