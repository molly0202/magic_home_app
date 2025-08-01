# 🔑 Firebase Authentication Setup

To run the programmatic import script, you need Firebase Admin SDK authentication.

## 🎯 OPTION 1: Service Account Key (Easiest)

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Select your project**: magic-home-01
3. **Navigate to**: Project Settings (gear icon) → Service Accounts
4. **Click**: "Generate new private key"
5. **Download**: The JSON file
6. **Rename**: The file to `serviceAccountKey.json`
7. **Move**: Put it in this project directory: `/Users/liyin/magic_home_app/`

## 🎯 OPTION 2: Google Cloud SDK (Alternative)

1. **Install Google Cloud SDK**: https://cloud.google.com/sdk/docs/install
2. **Authenticate**: `gcloud auth application-default login`
3. **Set project**: `gcloud config set project magic-home-01`

## 🚀 Running the Import

Once authentication is set up:

```bash
# Import all providers
node import_firestore.js

# Clear existing test providers
node import_firestore.js --clear

# Clear and then import fresh
node import_firestore.js --clear-and-import
```

## 🔒 Security Notes

- **Never commit** `serviceAccountKey.json` to Git
- **Keep** service account keys secure
- **Use** environment variables in production 