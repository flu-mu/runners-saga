// Firebase configuration for The Runner's Saga
const firebaseConfig = {
  apiKey: "AIzaSyAeqMmfnxCUCEz3N25bXoyRu2nxmDPKST0",
  authDomain: "runners-saga-app.firebaseapp.com",
  projectId: "runners-saga-app",
  storageBucket: "runners-saga-app.firebasestorage.app",
  messagingSenderId: "882096923572",
  appId: "1:882096923572:web:3ff068fb182606a0dbc8e1",
  measurementId: "G-12BPJ3ZJJ7"
};

// Google Sign-In configuration for web
const googleSignInConfig = {
  clientId: "882096923572-83p488filcuut9dd4h3qogbjehni7t2l.apps.googleusercontent.com"
};

// Make configuration available globally for Flutter
window.firebaseConfig = firebaseConfig;
window.googleSignInConfig = googleSignInConfig;

console.log('Firebase configuration loaded successfully');
console.log('Configuration available at window.firebaseConfig:', window.firebaseConfig);
console.log('Google Sign-In configuration available at window.googleSignInConfig:', window.googleSignInConfig);
