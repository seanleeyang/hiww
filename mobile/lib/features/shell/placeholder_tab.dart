import 'package:flutter/material.dart';

import '../../ui/empty_state.dart';
import 'app_shell.dart';

/// Temporary body for a shell tab whose real screen lands in a later phase.
class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key, required this.tab, required this.blurb});

  final ShellTab tab;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: tab.icon,
      title: '${tab.label} is coming soon',
      message: blurb,
    );
  }
}
