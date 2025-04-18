importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts(
    "https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js"
);

firebase.initializeApp({
    apiKey: "AIzaSyCdPnIFovrJzzGK0yHLdGs9UKA3CkmwoR8",
    appId: "1:1070956843093:web:1c4946ee7d1442116604dc",
    messagingSenderId: "1070956843093",
    projectId: "taskr-1428",
    authDomain: "taskr-1428.firebaseapp.com",
    storageBucket: "taskr-1428.firebasestorage.app",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log("Background message received:", payload);

    return self.registration.showNotification(
        notificationTitle,
        notificationOptions
    );
});
