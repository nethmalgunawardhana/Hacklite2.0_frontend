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

// Quiz questions data
const quizQuestions = [
  {
    question: 'Which communication method is most appropriate for someone who is both deaf and blind?',
    options: [
      'Lipreading',
      'Written notes',
      'Tactile sign language',
      'American Sign Language on video'
    ],
    correctAnswer: 2,
    hasImage: false,
    category: 'Accessibility',
    difficulty: 3,
    isActive: true,
  },
  {
    question: 'What is a common criticism of automated accessibility overlay tools?',
    options: [
      'They always required extensive manual auditing',
      'They replace the need for any compliance testing',
      'They mask underlying code issues without truly fixing accessibility barriers',
      'They increase page load speed dramatically.'
    ],
    correctAnswer: 2,
    hasImage: false,
    category: 'Accessibility',
    difficulty: 4,
    isActive: true,
  },
  {
    question: 'What does ADA stands for?',
    options: [
      'Accessible Development Act',
      'Association for Disabled Access',
      'American Disability Association',
      'Americans with Disabilities Act'
    ],
    correctAnswer: 3,
    hasImage: false,
    category: 'Legal',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'For an employee with a cognitive disability, which accommodation might improve job performance?',
    options: [
      'Limiting access to written instruction',
      'Breaking tasks into smaller, sequential steps',
      'Removing all deadlines',
      'Assigning more complex responsibilities'
    ],
    correctAnswer: 1,
    hasImage: false,
    category: 'Workplace',
    difficulty: 3,
    isActive: true,
  },
  {
    question: 'Under the ADA, public entities are required to provide sign language interpreters for',
    options: [
      'Crucial communication between public services and individuals with hearing disabilities',
      'All social events held by a public entity',
      'Only emergency announcements',
      'Voluntary public meeting without official business'
    ],
    correctAnswer: 0,
    hasImage: false,
    category: 'Legal',
    difficulty: 4,
    isActive: true,
  },
  {
    question: 'Which of the following is a hidden disability?',
    options: [
      'Amputation',
      'Blindness',
      'Spinal injury',
      'Dyslexia'
    ],
    correctAnswer: 3,
    hasImage: false,
    category: 'Awareness',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'What is the primary purpose of a screen reader?',
    options: [
      'To display images in higher resolution',
      'To convert text to speech for visually impaired users',
      'To automatically fix website accessibility issues',
      'To compress images for faster loading'
    ],
    correctAnswer: 1,
    hasImage: false,
    category: 'Technology',
    difficulty: 2,
    isActive: true,
  },
  {
    question: 'Which of these is considered a best practice for web accessibility?',
    options: [
      'Using only images for navigation',
      'Providing alternative text for images',
      'Using very small font sizes',
      'Relying only on color to convey information'
    ],
    correctAnswer: 1,
    hasImage: false,
    category: 'Web Development',
    difficulty: 3,
    isActive: true,
  },
  {
    question: 'What does WCAG stand for?',
    options: [
      'Web Content Accessibility Guidelines',
      'Worldwide Communication Access Group',
      'Web Compliance and Accessibility Guide',
      'Wireless Communication Accessibility Guidelines'
    ],
    correctAnswer: 0,
    hasImage: false,
    category: 'Standards',
    difficulty: 3,
    isActive: true,
  },
  {
    question: 'Which disability type might benefit most from captioning?',
    options: [
      'Mobility impairments',
      'Hearing impairments',
      'Cognitive disabilities',
      'Visual impairments'
    ],
    correctAnswer: 1,
    hasImage: false,
    category: 'Media',
    difficulty: 2,
    isActive: true,
  },
];

async function uploadQuizData() {
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
      console.log('4. Run: npm run upload (uses Admin SDK)');
      console.log('');
      return;
    }

    console.log('📝 Preparing quiz questions...');

    // Create quiz document
    const quizRef = doc(collection(db, 'quizzes'));
    await setDoc(quizRef, {
      title: 'Accessibility and ASL Knowledge Quiz',
      description: 'Test your knowledge about accessibility, sign language, and disability awareness',
      totalQuestions: quizQuestions.length,
      categories: ['Accessibility', 'Legal', 'Workplace', 'Awareness', 'Technology', 'Web Development', 'Standards', 'Media'],
      difficulty: 'Mixed',
      estimatedTime: 10, // minutes
      isActive: true,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    console.log('📋 Created quiz document:', quizRef.id);

    // Upload questions
    console.log('☁️ Uploading questions to Firestore...');
    let uploadedCount = 0;

    for (const question of quizQuestions) {
      const questionRef = await addDoc(collection(quizRef, 'questions'), {
        ...question,
        createdAt: serverTimestamp(),
      });
      uploadedCount++;
      console.log(`✅ Uploaded question ${uploadedCount}/${quizQuestions.length}: ${question.question.substring(0, 50)}...`);
    }

    console.log('🎉 Successfully uploaded all quiz questions!');
    console.log(`📊 Total questions uploaded: ${quizQuestions.length}`);
    console.log(`🆔 Quiz ID: ${quizRef.id}`);

    // Sign out
    await auth.signOut();
    console.log('👋 Signed out successfully');

  } catch (error) {
    console.error('❌ Error uploading quiz data:', error);

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
uploadQuizData();
