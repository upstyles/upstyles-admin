import 'package:flutter/material.dart';
/// Small set of reusable admin components for normalized UI.
/// These follow `AppTheme` tokens and opt into mobile-collapsed behavior.

class CollapsibleSearchBar extends StatefulWidget {
  final ValueChanged<String>? onSearch;
  final String initialValue;
  const CollapsibleSearchBar({super.key, this.onSearch, this.initialValue = ''});

  @override
  State<CollapsibleSearchBar> createState() => _CollapsibleSearchBarState();
}

class _CollapsibleSearchBarState extends State<CollapsibleSearchBar> {
  late bool _expanded;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    // default to collapsed on small screens; will be overridden in build
    _expanded = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Always default to collapsed; allow user to expand via icon
    final shouldCollapse = true; // kept for readability
    // Do not auto-expand — leave control to the user

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: _expanded ? 'Hide search' : 'Show search',
          onPressed: () => setState(() => _expanded = !_expanded),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: SizedBox(
            width: 260,
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: 'Search',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: (v) => widget.onSearch?.call(v),
            ),
          ),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AdminCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
