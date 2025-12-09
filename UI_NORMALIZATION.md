# Admin UI Normalization Spec

This spec standardizes UI/UX for the `upstyles_admin` dashboard. It follows the existing `AppTheme` tokens and decisions used across the project.

Goals:
- Maximize usable screen real-estate for mobile browsers by defaulting to compact/collapsed controls.
- Provide collapsible controls (search, filters) to reduce visual clutter.
- Reuse `AppTheme` colors and tokens; do not introduce a separate theme object.

Spacing scale (use `AppSpacing` where available):
- xs: 4
- s: 8
- m: 16
- l: 24
- xl: 32

Typography (map to `Theme.of(context).textTheme`):
- Title: `titleLarge` (bold)
- Section headings: `headlineSmall` / `bodyLarge` as appropriate
- Small metadata: `bodySmall`

Color tokens (from `AppTheme` / `ThemeData.colorScheme`):
- Primary actions: `Theme.of(context).colorScheme.primary` or `AppTheme.primaryColor`
- Success: `AppTheme.successColor`
- Warning: `AppTheme.warningColor`
- Muted text: `AppTheme.textSecondary` / `textTheme.bodySmall?.color`

Components to create and use:
- `CollapsibleSearchBar` — compact search input that expands when needed; hidden by default on small screens.
- `AdminCard` — consistent padding, border-radius, and elevation for list items.
- `SectionHeader` — title + optional actions (segmented controls / refresh) with consistent spacing.

Mobile behavior:
- On widths <= 600px, filters and search should default to collapsed. Provide an affordance (magnifier icon) to expand.
- Use `AnimatedCrossFade` or `SizeTransition` for smooth show/hide.

Accessibility:
- Ensure controls have tooltips and semantic labels for screen readers.

Implementation notes:
- Prefer `Theme.of(context)` values and `AppTheme` constants rather than hard-coded colors.
- Keep components small and composable so screens can opt-in gradually.
