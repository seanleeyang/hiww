import 'package:flutter/material.dart';

import '../core/countries.dart';

/// Country filter chips for the Trips browse tab — trips have no category of
/// their own (only a departure/arrival country), so country is the filter
/// dimension that actually applies to them. `null` value = "All".
class CountryChips extends StatelessWidget {
  const CountryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          for (final c in kLiveCountries) ...[
            ChoiceChip(
              label: Text(c.name),
              selected: selected == c.code,
              onSelected: (_) => onSelected(c.code),
            ),
            const SizedBox(width: 8),
          ],
          for (final c in kComingSoonCountries) ...[
            Chip(
              label: Text(c.name),
              avatar: Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
              backgroundColor: scheme.surfaceContainerHigh,
              labelStyle: TextStyle(color: scheme.onSurfaceVariant),
              side: BorderSide.none,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
