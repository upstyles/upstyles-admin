# Setup Option 3: Separate Firebase Projects

## Benefits
- **Maximum Security**: Complete isolation between user and admin infrastructure
- **Compliance**: Separate audit trails, easier to demonstrate controls
- **Access Control**: Different team members can have different permissions
- **Billing**: Separate costs for user vs admin operations
- **Monitoring**: Isolated metrics and alerting

## Steps

### 1. Create New Firebase Project

```bash
# Login to Firebase (if not already)
firebase login

# Create new project via Firebase Console:
# https://console.firebase.google.com
# Project name: upstyles-admin-pro
# Google Analytics: Optional
```

### 2. Update Local Configuration

```bash
cd /home/studio/Documents/stuff/UpStyles/upstyles_admin

# Update .firebaserc
cat > .firebaserc << 'FIREBASERC'
{
  "projects": {
    "default": "upstyles-admin-pro"
  }
}
FIREBASERC

# Get Firebase web config from:
# Firebase Console > Project Settings > Your apps > Web app
# Update lib/main.dart with new credentials
```

### 3. Enable Required Services

In Firebase Console for `upstyles-admin-pro`:
- [ ] Authentication > Enable Email/Password
- [ ] Firestore Database > Create database (production mode)
- [ ] Storage > Get started
- [ ] Hosting > Get started

### 4. Configure Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated moderators can read/write
    match /{document=**} {
      allow read, write: if request.auth != null 
        && request.auth.token.moderator == true;
    }
  }
}
```

### 5. Create Moderator Users

```bash
# In Firebase Console > Authentication
# Add users manually with Email/Password
# Then set custom claims via Firebase CLI:

firebase functions:shell
> const admin = require('firebase-admin');
> admin.auth().setCustomUserClaims('USER_UID_HERE', {moderator: true, role: 'admin'});
```

### 6. Update Shared Resources

**Firestore Data Access:**
- Admin app reads from `upstyles-pro` (user data)
- Admin app writes audit logs to `upstyles-admin-pro`
- Configure Firebase Admin SDK in moderation-api to access both projects

**Moderation API Update:**
```javascript
// Add second Firebase app for admin project
const adminApp = admin.initializeApp({
  projectId: 'upstyles-admin-pro'
}, 'admin');

const adminDb = adminApp.firestore();
```

### 7. Deploy

```bash
# Build
flutter build web --release --no-wasm-dry-run --dart-define-from-file=dart_defines.json

# Deploy
firebase deploy --only hosting

# Access at: https://upstyles-admin-pro.web.app
```

### 8. Update dart_defines.json

```json
{
  "ENVIRONMENT": "production",
  "MODERATION_API_BASE_URL": "https://moderation-api--upstyles-pro.us-east4.hosted.app",
  "FIREBASE_PROJECT_ID": "upstyles-admin-pro",
  "USER_FIREBASE_PROJECT_ID": "upstyles-pro"
}
```

## Security Checklist

- [ ] Separate Firebase projects created
- [ ] Admin project has restrictive Firestore rules
- [ ] Only moderators have accounts in admin project
- [ ] User project Firestore rules don't allow admin operations
- [ ] Moderation API validates tokens from both projects
- [ ] Audit logs written to admin project only
- [ ] No shared credentials between projects
- [ ] Different billing alerts configured
- [ ] Separate monitoring dashboards

## Cost Implications

**Pros:**
- Clear separation of costs
- Can optimize each project independently
- Easier budgeting and forecasting

**Cons:**
- Slightly higher base costs (2x free tier limits used)
- More complexity in monitoring

**Estimated Additional Cost**: $0-5/month for low admin traffic

## Compliance Benefits

✅ **SOC 2**: Separate access controls, audit trails  
✅ **GDPR**: Clear data processor boundaries  
✅ **HIPAA**: If needed, only admin project requires compliance  
✅ **ISO 27001**: Easier to demonstrate segregation of duties

## Rollback Plan

If issues arise:
1. Keep both projects running
2. Deploy admin app to user project temporarily
3. Redirect DNS to fallback
4. Debug separate project issues
5. Re-deploy when resolved

