const { initializeApp } = require('firebase/app');
const { getFirestore, collection, doc, setDoc, addDoc, serverTimestamp } = require('firebase/firestore');
const { getAuth, signInAnonymously } = require('firebase/auth');

// Firebase configuration from google-services.json
const firebaseConfig = {
  apiKey: "AIzaSyDmlUKgAnMmGe51K18V1FEpX37UY0ZdFrk",
  authDomain: "hacklite-9c06e.firebaseapp.com",
  projectId: "hacklite-9c06e",
  storageBucket: "hacklite-9c06e.firebasestorage.app",
  messagingSenderId: "940330317059",
  appId: "1:940330317059:web:a1b2c3d4e5f6g7h8i9j0"
};

// ASL Signs Quiz Questions
const aslQuizQuestions = [
  {
    question: 'What letter does this ASL sign represent?',
    options: ['A', 'B', '2', '3'],
    correctAnswer: 2,
    hasImage: true,
    imageUrl: 'images/11.webp',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What letter does this ASL sign represent?',
    options: ['K', 'L', 'M', 'N'],
    correctAnswer: 0,
    hasImage: true,
    imageUrl: 'images/Sign-Language-M-.webp',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What does this ASL sign mean?',
    options: ['Hello', 'Please', 'Thank you', 'Goodbye'],
    correctAnswer: 1,
    hasImage: true,
    imageUrl: 'images/Sign-Language-Please-.webp',
    category: 'ASL Words',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What does this ASL sign mean?',
    options: ['Eat', 'Drink', 'Lunch', 'Dinner'],
    correctAnswer: 2,
    hasImage: true,
    imageUrl: 'images/Sign-Language-Eat-Lunch-.webp',
    category: 'ASL Words',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What does this ASL sign mean?',
    options: ['Bathroom', 'Water', 'Wash', 'Clean'],
    correctAnswer: 0,
    hasImage: true,
    imageUrl: 'images/Sign-Language-Potty-.webp',
    category: 'ASL Words',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What letter does this ASL sign represent?',
    options: ['Y', 'X', 'Z', 'W'],
    correctAnswer: 0,
    hasImage: true,
    imageUrl: 'images/18.png',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What letter does this ASL sign represent?',
    options: ['G', 'H', 'I', 'J'],
    correctAnswer: 0,
    hasImage: true,
    imageUrl: 'images/sign1.png',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What letter does this ASL sign represent?',
    options: ['P', 'Q', 'R', 'S'],
    correctAnswer: 0,
    hasImage: true,
    imageUrl: 'images/Sign-Language-Please-.webp',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What letter does this ASL sign represent?',
    options: ['M', 'N', 'O', 'P'],
    correctAnswer: 2,
    hasImage: true,
    imageUrl: 'images/Sign-Language-M-.webp',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What letter does this ASL sign represent?',
    options: ['Q', 'R', 'S', 'T'],
    correctAnswer: 0,
    hasImage: true,
    imageUrl: 'images/Sign-Language-Potty-.webp',
    category: 'ASL Alphabet',
    difficulty: 2,
    isActive: true,
  },
];

async function uploadASLQuizData() {
  try {
    console.log('🚀 Initializing Firebase...');

    // Initialize Firebase
    const app = initializeApp(firebaseConfig);
    const db = getFirestore(app);
    const auth = getAuth(app);

    console.log('🔐 Attempting to sign in anonymously...');

    // Try anonymous sign-in first
    try {
      await signInAnonymously(auth);
      console.log('✅ Signed in anonymously');
    } catch (anonError) {
      console.log('❌ Anonymous authentication failed:', anonError.message);
      console.log('');
      console.log('🔧 To fix this issue, you have two options:');
      console.log('');
      console.log('Option 1: Enable Anonymous Authentication');
      console.log('1. Go to Firebase Console: https://console.firebase.google.com/');
      console.log('2. Select your project: hacklite-9c06e');
      console.log('3. Go to Authentication → Sign-in method');
      console.log('4. Enable "Anonymous" sign-in method');
      console.log('5. Run this script again');
      console.log('');
      console.log('Option 2: Use Service Account (Recommended for server operations)');
      console.log('1. Go to Firebase Console → Project Settings → Service Accounts');
      console.log('2. Click "Generate new private key"');
      console.log('3. Download and save as service-account-key.json');
      console.log('4. Run: npm run upload-asl (uses Admin SDK)');
      console.log('');
      return;
    }

    console.log('📝 Preparing ASL quiz questions...');

    // Create ASL quiz document
    const quizRef = doc(collection(db, 'quizzes'));
    await setDoc(quizRef, {
      title: 'American Sign Language (ASL) Recognition Quiz',
      description: 'Test your knowledge of ASL signs and alphabet',
      totalQuestions: aslQuizQuestions.length,
      categories: ['ASL Alphabet', 'ASL Words'],
      difficulty: 'Beginner',
      estimatedTime: 8, // minutes
      isActive: true,
      quizType: 'asl',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    console.log('📋 Created ASL quiz document:', quizRef.id);

    // Upload ASL questions
    console.log('☁️ Uploading ASL questions to Firestore...');
    let uploadedCount = 0;

    for (const question of aslQuizQuestions) {
      const questionRef = await addDoc(collection(quizRef, 'questions'), {
        ...question,
        createdAt: serverTimestamp(),
      });
      uploadedCount++;
      console.log(`✅ Uploaded ASL question ${uploadedCount}/${aslQuizQuestions.length}: ${question.question.substring(0, 50)}...`);
    }

    console.log('🎉 Successfully uploaded all ASL quiz questions!');
    console.log(`📊 Total ASL questions uploaded: ${aslQuizQuestions.length}`);
    console.log(`🆔 ASL Quiz ID: ${quizRef.id}`);

    // Sign out
    await auth.signOut();
    console.log('👋 Signed out successfully');

  } catch (error) {
    console.error('❌ Error uploading ASL quiz data:', error);

    if (error.code === 'permission-denied') {
      console.log('\n💡 Firestore Security Rules Issue:');
      console.log('Your Firestore security rules are preventing writes.');
      console.log('You need to update your Firestore rules to allow authenticated users to write.');
      console.log('\nExample Firestore Rules:');
      console.log('rules_version = \'2\';');
      console.log('service cloud.firestore {');
      console.log('  match /databases/{database}/documents {');
      console.log('    match /{document=**} {');
      console.log('      allow read, write: if request.auth != null;');
      console.log('    }');
      console.log('  }');
      console.log('}');
    } else if (error.code === 'unavailable') {
      console.log('\n💡 Network Issue:');
      console.log('Check your internet connection and Firebase project configuration.');
    }
  }
}

// Run the upload function
uploadASLQuizData();
