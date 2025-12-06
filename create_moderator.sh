#!/bin/bash

echo "🔐 UpStyles Admin - Create Moderator Account"
echo ""
echo "First, create the user in Firebase Console:"
echo "https://console.firebase.google.com/project/upstyles-admin-pro/authentication"
echo ""
read -p "Have you created the user account? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Please create the account first, then run this script again."
    exit 1
fi

echo ""
read -p "Enter the user's email: " EMAIL

echo ""
echo "🔄 Setting moderator claims..."

curl -X POST \
  https://us-central1-upstyles-admin-pro.cloudfunctions.net/setModeratorClaims \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$EMAIL\", \"secret\": \"SETUP_SECRET_2024\"}" \
  | python3 -m json.tool

echo ""
echo ""
echo "✅ Done! The user should now be able to login at:"
echo "   https://upstyles-admin-pro.web.app"
echo ""
echo "📋 To list all moderators, run:"
echo "   curl 'https://us-central1-upstyles-admin-pro.cloudfunctions.net/listModerators?secret=SETUP_SECRET_2024'"
