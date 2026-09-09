// Web push service worker — required by firebase_messaging's web
// implementation to show a notification while the Hiww tab is closed or in
// the background. Loaded automatically from the site root; no manual
// registration needed on the Dart side.
//
// PLACEHOLDER CONFIG: fill this in with the same Web app config values from
// your Firebase project (Project settings -> General -> Your apps -> Web
// app) that you put in mobile/lib/firebase_options.dart's `web` block. Until
// then this worker loads but can't actually authenticate with Firebase, so
// web push silently does nothing (no crash) — see that file's setup steps.

importScripts('https://www.gstatic.com/firebasejs/12.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.3.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_WITH_WEB_API_KEY',
  appId: 'REPLACE_WITH_WEB_APP_ID',
  messagingSenderId: 'REPLACE_WITH_SENDER_ID',
  projectId: 'REPLACE_WITH_PROJECT_ID',
});

const messaging = firebase.messaging();

// Background messages (tab closed/backgrounded) — foreground messages are
// handled in Dart via FirebaseMessaging.onMessage instead.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Hiww';
  const options = {
    body: payload.notification?.body,
    icon: '/icons/Icon-192.png',
    data: payload.data,
  };
  self.registration.showNotification(title, options);
});

// Tapping the OS notification focuses/opens the app; navigation to the
// specific screen (payload.data.link) happens once the app is running, via
// FirebaseMessaging.onMessageOpenedApp / getInitialMessage in Dart.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});
