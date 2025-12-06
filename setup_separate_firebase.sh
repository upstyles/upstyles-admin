#!/bin/bash

echo "🔐 Setting up UpStyles Admin with Separate Firebase Project"
echo ""
echo "Prerequisites:"
echo "1. You must have created 'upstyles-admin-pro' project in Firebase Console"
echo "2. Enabled Authentication, Firestore, and Hosting in that project"
echo ""
read -p "Have you completed these steps? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "❌ Please complete prerequisites first:"
    echo "   https://console.firebase.google.com"
    exit 1
fi

echo ""
echo "📝 Please provide your Firebase Admin Project credentials"
echo "   (Found in Firebase Console > Project Settings > Web app)"
echo ""

read -p "API Key: " API_KEY
read -p "Auth Domain (e.g., upstyles-admin-pro.firebaseapp.com): " AUTH_DOMAIN
read -p "Project ID (upstyles-admin-pro): " PROJECT_ID
read -p "Storage Bucket (e.g., upstyles-admin-pro.firebasestorage.app): " STORAGE_BUCKET
read -p "Messaging Sender ID: " MESSAGING_SENDER_ID
read -p "App ID: " APP_ID

echo ""
echo "🔧 Updating configuration files..."

# Update .firebaserc
cat > .firebaserc << FIREBASERC
{
  "projects": {
    "default": "$PROJECT_ID"
  }
}
FIREBASERC

# Update dart_defines.json
cat > dart_defines.json << DEFINES
{
  "ENVIRONMENT": "production",
  "MODERATION_API_BASE_URL": "https://moderation-api--upstyles-pro.us-east4.hosted.app",
  "FIREBASE_PROJECT_ID": "$PROJECT_ID",
  "USER_FIREBASE_PROJECT_ID": "upstyles-pro"
}
DEFINES

# Update main.dart with new Firebase config
sed -i "s/apiKey: \".*\"/apiKey: \"$API_KEY\"/" lib/main.dart
sed -i "s/authDomain: \".*\"/authDomain: \"$AUTH_DOMAIN\"/" lib/main.dart
sed -i "s/projectId: \".*\"/projectId: \"$PROJECT_ID\"/" lib/main.dart
sed -i "s/storageBucket: \".*\"/storageBucket: \"$STORAGE_BUCKET\"/" lib/main.dart
sed -i "s/messagingSenderId: \".*\"/messagingSenderId: \"$MESSAGING_SENDER_ID\"/" lib/main.dart
sed -i "s/appId: \".*\"/appId: \"$APP_ID\"/" lib/main.dart

echo "✅ Configuration updated!"
echo ""
echo "🔐 Next steps:"
echo "1. Deploy Firestore security rules:"
echo "   firebase deploy --only firestore:rules"
echo ""
echo "2. Create moderator account in Firebase Console:"
echo "   https://console.firebase.google.com/project/$PROJECT_ID/authentication"
echo ""
echo "3. Set custom claims (run in Firebase Functions shell):"
echo "   firebase functions:shell"
echo "   > admin.auth().setCustomUserClaims('USER_UID', {moderator: true})"
echo ""
echo "4. Build and deploy:"
echo "   flutter build web --release --no-wasm-dry-run --dart-define-from-file=dart_defines.json"
echo "   firebase deploy --only hosting"
echo ""
echo "🎉 Admin app will be at: https://$PROJECT_ID.web.app"

