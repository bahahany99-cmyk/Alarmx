// Shared editor card chrome (alarm-editor refresh).
//
// [EditorCard] gives every section of the create/edit form one modern
// container: a softly elevated Material 3 card with large rounded
// corners. Sections keep their own content and keys; only the frame is
// shared, so visual consistency never drifts per-section.

import 'package:flutter/material.dart';

/// Modern rounded container for one editor section; see the file docs.
class EditorCard extends StatelessWidget {
  const EditorCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Tonal chip behind a section icon.
class EditorHeaderIcon extends StatelessWidget {
  const EditorHeaderIcon(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      child: Icon(icon, size: 18),
    );
  }
}
