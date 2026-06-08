// Service worker for Firebase Cloud Messaging on the web.
//
// Phase 6.2 — registered automatically by `firebase_messaging` on web
// when it boots. Handles background pushes (tab closed / minimised);
// foreground pushes are delivered via the existing `onMessage` listener
// in `FcmHandler`.
//
// The Firebase JS SDK in a service worker MUST use the `-compat` builds
// (the modular SDK can't run inside a worker because it relies on dynamic
// imports that aren't available in this context).
//
// Project configuration is **hardcoded** because the service worker
// loads outside the Flutter app — `firebase_options.dart` isn't reachable.
// Keep this file in sync with `lib/firebase_options*.dart`:
//   * dev   → projectId `crewpoint-dev`   (default; ships as-is)
//   * stg   → projectId `crewpoint-stg`   (edit before deploying)
//   * prod  → projectId `crewpoint-prod`  (edit before deploying)
// A per-flavor build script can replace this file at deploy time if
// flavor parity is needed.
//
// Reference: https://firebase.google.com/docs/cloud-messaging/js/receive

importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js'
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js'
);

firebase.initializeApp({
  apiKey: 'AIzaSyAgvlcN_IZRe8XXAtFS_qVGrSBkIwPiZVo',
  appId: '1:711822236757:web:7fc7f232d8f717188788dc',
  messagingSenderId: '711822236757',
  projectId: 'crewpoint-dev',
  authDomain: 'crewpoint-dev.firebaseapp.com',
  storageBucket: 'crewpoint-dev.firebasestorage.app',
});

// `firebase.messaging()` registers the worker with Firebase. The default
// `onBackgroundMessage` handler renders the `notification` payload as a
// system notification — that's exactly the V1 behaviour we want, so no
// custom handler is wired here. Add one only if you need to inspect /
// transform the payload before the OS notification is shown.
firebase.messaging();
