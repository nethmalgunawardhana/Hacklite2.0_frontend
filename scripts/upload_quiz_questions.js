const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Try to initialize Firebase Admin SDK with different methods
async function initializeFirebase() {
  try {
    // Method 1: Try service account key file
    const serviceAccountPath = path.join(__dirname, 'service-account-key.json');
    if (fs.existsSync(serviceAccountPath)) {
      console.log('🔑 Using service account key file...');
      const serviceAccount = require(serviceAccountPath);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'hacklite-9c06e'
      });
      return;
    }

    // Method 2: Try environment variables
    if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
      console.log('🔑 Using environment variable for service account...');
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: 'hacklite-9c06e'
      });
      return;
    }

    // Method 3: Try application default credentials (for Google Cloud environments)
    console.log('🔑 Using application default credentials...');
    admin.initializeApp({
      projectId: 'hacklite-9c06e'
    });

  } catch (error) {
    console.error('❌ Failed to initialize Firebase:', error.message);
    throw new Error(
      'Firebase initialization failed. Please ensure you have:\n' +
      '1. A service-account-key.json file in the scripts directory, OR\n' +
      '2. FIREBASE_SERVICE_ACCOUNT_KEY environment variable set, OR\n' +
      '3. Are running in a Google Cloud environment with default credentials\n\n' +
      'To get the service account key:\n' +
      '1. Go to Firebase Console → Project Settings → Service Accounts\n' +
      '2. Click "Generate new private key"\n' +
      '3. Download and rename to service-account-key.json\n' +
      '4. Place in the scripts/ directory'
    );
  }
}

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
  // Additional questions
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

async function uploadQuizQuestions() {
  try {
    console.log('🚀 Initializing Firebase...');
    await initializeFirebase();

    const db = admin.firestore();
    console.log('📝 Preparing quiz questions...');
    const questions = quizQuestions;
    const quizRef = db.collection('quizzes').doc();
    await quizRef.set({
      title: 'Accessibility and ASL Knowledge Quiz',
      description: 'Test your knowledge about accessibility, sign language, and disability awareness',
      totalQuestions: quizQuestions.length,
      categories: ['Accessibility', 'Legal', 'Workplace', 'Awareness', 'Technology', 'Web Development', 'Standards', 'Media'],
      difficulty: 'Mixed',
      estimatedTime: 10, // minutes
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log('📋 Created quiz document:', quizRef.id);

    // Upload questions in batches
    const batch = db.batch();
    let questionCount = 0;

        for (const question of quizQuestions) {
      const questionRef = quizRef.collection('questions').doc();
      batch.set(questionRef, {
        ...question,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      questionCount++;

      // Commit batch every 10 questions
      if (questionCount % 10 === 0) {
        await batch.commit();
        console.log(`📤 Uploaded batch of 10 questions... (${questionCount}/${quizQuestions.length})`);
        // Start new batch
      }
    }

    // Commit remaining questions
    if (questionCount % 10 !== 0) {
      await batch.commit();
      console.log(`📤 Uploaded final batch of ${questionCount % 10} questions...`);
    }

    console.log('✅ Successfully uploaded all quiz questions!');
    console.log(`📊 Total questions uploaded: ${quizQuestions.length}`);

  } catch (error) {
    console.error('❌ Error uploading questions:', error);
  } finally {
    // Close the Firebase app
    await admin.app().delete();
  }
}

// Run the upload function
uploadQuizQuestions();
