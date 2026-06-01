importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCCWJN5-ik7w6VdVMB9c-EZmQKRYyyxEgw',
  appId: '1:708777510505:web:1bafdcd9c3dd0a00b604f8',
  messagingSenderId: '708777510505',
  projectId: 'naliv-web-test',
  authDomain: 'naliv-web-test.firebaseapp.com',
  storageBucket: 'naliv-web-test.firebasestorage.app',
  measurementId: 'G-PRQBG0PR9Q',
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