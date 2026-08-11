importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCScRucA7l3xPfEtccayOrvYeWgJ8kQ9VU',
  authDomain: 'bank-of-mom-and-dad-ho.firebaseapp.com',
  projectId: 'bank-of-mom-and-dad-ho',
  messagingSenderId: '109157925075',
  appId: '1:109157925075:web:b80ce6c81d4caf6fe05426',
});

// Payloads sent with a `notification` field display automatically in the background.
firebase.messaging();
