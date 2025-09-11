const admin = require('firebase-admin');

// Alternative initialization using Firebase config (easier setup)
const firebaseConfig = {
  apiKey: 'AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk',
  authDomain: 'hacklite-9c06e.firebaseapp.com',
  projectId: 'hacklite-9c06e',
  storageBucket: 'hacklite-9c06e.firebasestorage.app',
  messagingSenderId: '940330317059',
  appId: '1:940330317059:web:a1b2c3d4e5f6g7h8i9j0'
};

// For this to work, you need to set up authentication
// Option 1: Use Firebase CLI (recommended)
console.log('🔧 To use this script, you have two options:');
console.log('');
console.log('Option 1 - Firebase CLI (Recommended):');
console.log('1. Install Firebase CLI: npm install -g firebase-tools');
console.log('2. Login: firebase login');
console.log('3. Set project: firebase use hacklite-9c06e');
console.log('4. Run: firebase functions:config:set firebase.service_account_key="$(cat service-account-key.json)"');
console.log('');
console.log('Option 2 - Environment Variable:');
console.log('1. Set environment variable:');
console.log('   Windows: $env:FIREBASE_SERVICE_ACCOUNT_KEY = Get-Content service-account-key.json -Raw');
console.log('   Linux/Mac: export FIREBASE_SERVICE_ACCOUNT_KEY=$(cat service-account-key.json)');
console.log('2. Then run the main script');
console.log('');
console.log('❌ This script cannot run directly. Please use one of the options above.');

process.exit(1);
