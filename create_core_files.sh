#!/bin/bash

# Copy and adapt key files from main app
cp upstyles_app/lib/src/services/moderation_api_service.dart upstyles_admin/lib/src/services/
cp upstyles_app/lib/src/screens/moderation/explore_submissions_tab.dart upstyles_admin/lib/src/screens/submissions/
cp upstyles_app/lib/src/screens/moderation/analytics_tab.dart upstyles_admin/lib/src/screens/analytics/
cp upstyles_app/lib/src/screens/moderation/users_moderation_tab.dart upstyles_admin/lib/src/screens/users/
cp upstyles_app/lib/src/screens/moderation/audit_log_tab.dart upstyles_admin/lib/src/screens/audit/
cp upstyles_app/lib/src/utils/logger.dart upstyles_admin/lib/src/utils/

echo "✅ Core files copied from main app"
