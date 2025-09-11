# Quiz Upload Scripts

### Option 3: ASL Quiz (Image-based)
```bash
# Upload ASL recognition quiz with images
npm run upload-asl
```

**Features:**
- 10 ASL sign recognition questions
- Mix of alphabet letters and common words
- Uses images from the `images/` folder
- Includes signs for: 2, K, M, Please, Eat/Lunch, Potty, Y, G, P, O, Qy contains scripts for managing quiz data in Firestore.

## 🚀 Quick Start (Easiest Method)

### Option 1: Firebase CLI (Recommended)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Set your project
firebase use hacklite-9c06e

# Get service account key from Firebase Console
# Go to: Project Settings → Service Accounts → Generate new private key
# Download and save as service-account-key.json in this directory

# Run the upload script
npm run upload
```

### Option 2: Manual Setup
```bash
# Get service account key from Firebase Console
# Go to: https://console.firebase.google.com/project/hacklite-9c06e/settings/serviceaccounts/adminsdk
# Generate new private key → Download JSON → Rename to service-account-key.json
# Place in scripts/ directory

# Install dependencies
npm install

# Run upload
npm run upload
```

### Option 4: Web SDK (Using Your google-services.json)
```bash
# First, enable anonymous authentication:
npm run setup-auth

# Then enable anonymous auth in Firebase Console (follow the printed instructions)

# Finally, run the upload:
npm run upload-web
```

**Note:** This method requires enabling anonymous authentication in Firebase Console. The setup script will show you exactly what to do.

## 📁 File Structure

```
scripts/
├── upload_quiz_questions.js    # Main accessibility quiz upload script
├── upload_quiz_web_sdk.js      # Web SDK accessibility quiz upload script
├── upload_asl_quiz.js          # ASL image-based quiz upload script
├── package.json               # Dependencies and scripts
├── README.md                  # This file
├── .gitignore                 # Git ignore rules
└── service-account-key.json   # Your Firebase credentials (create this)
```

## 🔧 What the Script Does

1. **Authenticates** with Firebase using your service account
2. **Creates a quiz document** in the `quizzes` collection
3. **Uploads 10 quiz questions** as subdocuments
4. **Sets up categories and difficulty levels**

## 📊 Firestore Structure Created

```
quizzes/{quizId}/
├── title: "Accessibility and ASL Knowledge Quiz"
├── description: "..."
├── totalQuestions: 10
├── categories: ["Accessibility", "Legal", ...]
├── isActive: true
└── questions/{questionId}/
    ├── question: "What does ADA stand for?"
    ├── options: ["...", "...", "...", "..."]
    ├── correctAnswer: 3
    ├── category: "Legal"
    ├── difficulty: 2
    └── isActive: true
```

## 🛡️ Firestore Security Rules

If you're using the Web SDK method, you may need to update your Firestore security rules to allow authenticated users to write data:

### Basic Rules for Testing:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### More Secure Rules (Recommended for Production):
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /quizzes/{quizId} {
      allow read: if true;
      allow write: if request.auth != null && 
        (request.auth.token.email in ['your-admin-email@example.com'] || 
         request.auth.token.admin == true);
    }
    match /quizzes/{quizId}/questions/{questionId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

**To update Firestore rules:**
1. Go to Firebase Console → Firestore Database → Rules
2. Update the rules
3. Click "Publish"

## 🐛 Troubleshooting

### "Cannot find module './service-account-key.json'"
- Make sure you have the service account key file in the scripts directory
- Follow the setup instructions above to get the key

### "Firebase initialization failed"
- Check that your service account key is valid
- Verify the project ID matches your Firebase project
- Try the environment variable method

### Permission Denied
- Make sure your service account has Firestore access
- Check Firestore security rules allow writes

## 📝 Questions Included

### Accessibility Quiz
The main quiz uploads 10 accessibility-focused quiz questions covering:
- Communication methods for deaf/blind individuals
- Accessibility tools and criticisms
- Legal frameworks (ADA)
- Workplace accommodations
- Web accessibility best practices
- Disability awareness

### ASL Recognition Quiz
The ASL quiz includes 10 image-based questions covering:
- ASL alphabet signs: 2, K, M, Y, G, P, O, Q
- Common ASL words: Please, Eat/Lunch, Potty
- Visual recognition and identification
- Beginner to intermediate difficulty levels

You can modify the questions in the respective upload scripts and re-run them to update Firestore.
