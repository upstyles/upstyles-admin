#!/bin/bash

# Create directory structure
mkdir -p assets/images
mkdir -p lib/src/{screens,services,providers,models,utils,widgets}
mkdir -p lib/src/screens/{auth,dashboard,submissions,analytics,users,audit}

# Create dart_defines.json
cat > dart_defines.json << 'EOF'
{
  "ENVIRONMENT": "production",
  "MODERATION_API_BASE_URL": "https://moderation-api--upstyles-pro.us-east4.hosted.app",
  "FIREBASE_PROJECT_ID": "upstyles-pro"
}
EOF

# Create firebase.json
cat > firebase.json << 'EOF'
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
EOF

# Create .firebaserc
cat > .firebaserc << 'EOF'
{
  "projects": {
    "default": "upstyles-pro"
  }
}
EOF

echo "✅ Project structure and config files created"
