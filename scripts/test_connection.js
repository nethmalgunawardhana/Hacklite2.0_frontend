const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Test Firebase connection
async function testFirebaseConnection() {
  try {
    console.log('🧪 Testing Firebase connection...');

    // Try different authentication methods
    let initialized = false;

    // Method 1: Service account file
    const serviceAccountPath = path.join(__dirname, 'service-account-key.json');
    if (fs.existsSync(serviceAccountPath)) {
      console.log('✅ Found service account key file');
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'hacklite-9c06e'
      });
      initialized = true;
    }

    // Method 2: Environment variable
    if (!initialized && process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
      console.log('✅ Found environment variable');
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'hacklite-9c06e'
      });
      initialized = true;
    }

    // Method 3: Application default credentials
    if (!initialized) {
      console.log('⚠️  No explicit credentials found, trying application default...');
      admin.initializeApp({
        projectId: 'hacklite-9c06e'
      });
      initialized = true;
    }

    if (!initialized) {
      console.log('❌ No authentication method available');
      console.log('');
      console.log('🔧 To fix this:');
      console.log('1. Get service account key from Firebase Console');
      console.log('2. Save as service-account-key.json in this directory');
      console.log('3. Or set FIREBASE_SERVICE_ACCOUNT_KEY environment variable');
      return;
    }

    // Test Firestore connection
    const db = admin.firestore();
    console.log('🔗 Testing Firestore connection...');

    // Try to read from a collection (this will fail gracefully if no data exists)
    const testQuery = await db.collection('quizzes').limit(1).get();

    console.log('✅ Firebase connection successful!');
    console.log(`📊 Found ${testQuery.size} quiz documents in Firestore`);

    // Clean up
    await admin.app().delete();
    console.log('🧹 Connection test completed');

  } catch (error) {
    console.error('❌ Firebase connection failed:', error.message);

    if (error.code === 'ENOENT') {
      console.log('💡 Tip: Make sure service-account-key.json exists in this directory');
    } else if (error.message.includes('permission-denied')) {
      console.log('💡 Tip: Check your Firestore security rules');
    } else if (error.message.includes('invalid-credential')) {
      console.log('💡 Tip: Verify your service account key is valid');
    }
  }
}

// Run the test
testFirebaseConnection();
