import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../submissions/explore_submissions_tab.dart';
import '../analytics/analytics_tab.dart';
import '../users/users_moderation_tab.dart';
import '../posts/posts_moderation_tab.dart';
import '../reports/reports_moderation_tab.dart';
import '../audit/audit_log_tab.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/theme_settings_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isRailCollapsed = false;

  final List<Widget> _tabs = const [
    ExploreSubmissionsTab(),
    UsersModerationTab(),
    PostsModerationTab(),
    ReportsModerationTab(),
    AnalyticsTab(),
    AuditLogTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings),
            SizedBox(width: 12),
            Text('UpStyles Admin Dashboard'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(user?.email ?? 'Admin'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () => _showThemeDialog(context),
                  tooltip: 'Theme Settings',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  tooltip: 'Sign Out',
                ),
              ],
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.8),
                ],
              ),
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    extended: !_isRailCollapsed,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    labelType: _isRailCollapsed ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                    leading: !_isRailCollapsed ? const SizedBox(height: 20) : null,
                    destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.article_outlined),
                selectedIcon: Icon(Icons.article),
                label: Text('Submissions'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outlined),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.feed_outlined),
                selectedIcon: Icon(Icons.feed),
                label: Text('Posts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.flag_outlined),
                selectedIcon: Icon(Icons.flag),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.history),
                selectedIcon: Icon(Icons.history),
                label: Text('Audit Log'),
              ),
            ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: IconButton(
                    icon: Icon(
                      _isRailCollapsed ? Icons.chevron_right : Icons.chevron_left,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _isRailCollapsed = !_isRailCollapsed);
                    },
                    tooltip: _isRailCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _tabs[_selectedIndex],
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ThemeSettingsDialog(),
    );
  }
}
