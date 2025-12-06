# Deployment Guide

## Quick Deploy

```bash
# Build
flutter build web --release --no-wasm-dry-run --dart-define-from-file=dart_defines.json

# Deploy to Firebase
firebase deploy --only hosting
```

## Setup New Hosting (if needed)

```bash
# Login
firebase login

# Initialize (only once)
firebase init hosting

# Select:
# - Use existing project: upstyles-pro
# - Public directory: build/web
# - Configure as SPA: Yes
# - Setup automatic builds: No
```

## Environment Variables

Configured in `dart_defines.json`:
- MODERATION_API_BASE_URL
- FIREBASE_PROJECT_ID
- ENVIRONMENT

## Post-Deployment

1. Access: https://upstyles-admin-pro.web.app
2. Login with moderator account
3. Verify all tabs load correctly
4. Test batch operations

## Security Checklist

- [ ] Firebase Authentication enabled
- [ ] Custom claims for moderator role
- [ ] Firestore rules restrict to moderators
- [ ] API validates authentication tokens
- [ ] CORS configured correctly

## Monitoring

- Firebase Console: https://console.firebase.google.com
- Check hosting metrics
- Review authentication logs
- Monitor API usage
