# UpStyles Admin Dashboard

Standalone moderation and administration web application for UpStyles platform.

## Features

- 🔐 **Secure Authentication** - Firebase Auth with admin/moderator roles
- 📊 **Real-time Analytics** - Live stats from Firestore
- ✅ **Batch Operations** - Approve/reject multiple submissions at once
- 👥 **User Management** - Quality scores and contributor levels
- 📝 **Audit Log** - Complete moderation history
- 🎨 **Material Design 3** - Modern, responsive UI

## Why Standalone App?

- **Security**: Keeps admin functionality separate from user app
- **Compliance**: Easier to manage admin access and permissions
- **Performance**: Smaller main app size
- **Maintenance**: Independent deployment cycles

## Tech Stack

- Flutter Web (web-only)
- Firebase (Auth, Firestore, Storage)
- Go Router for navigation
- Provider for state management
- Material Design 3

## Development

### Prerequisites

- Flutter SDK 3.5.4+
- Firebase CLI
- Node.js (for Firebase functions)

### Setup

```bash
# Install dependencies
flutter pub get

# Run locally
flutter run -d chrome --dart-define-from-file=dart_defines.json

# Build for production
flutter build web --release --dart-define-from-file=dart_defines.json
```

### Firebase Deployment

```bash
# Login to Firebase
firebase login

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

The app will be available at: `https://upstyles-admin-pro.web.app`

## Configuration

Create `dart_defines.json`:

```json
{
  "ENVIRONMENT": "production",
  "MODERATION_API_BASE_URL": "https://moderation-api--upstyles-pro.us-east4.hosted.app",
  "FIREBASE_PROJECT_ID": "upstyles-pro"
}
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
└── src/
    ├── screens/
    │   ├── auth/               # Login screen
    │   ├── dashboard/          # Main dashboard
    │   ├── submissions/        # Content moderation
    │   ├── analytics/          # Stats & insights
    │   ├── users/              # User management
    │   └── audit/              # Audit log
    ├── services/               # API services
    ├── providers/              # State management
    ├── models/                 # Data models
    ├── widgets/                # Reusable components
    └── utils/                  # Utilities
```

## Security

- Firebase Authentication with custom claims
- Server-side validation via moderation-api
- Role-based access control (moderator/admin)
- Audit logging for all actions

## License

Proprietary - UpStyles Platform
