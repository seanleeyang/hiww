import 'package:flutter/material.dart';

import '../core/countries.dart';
import '../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(l10n.categoryAll),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          for (final c in kLiveCountries) ...[
            ChoiceChip(
              label: Text(countryName(c.code, l10n.localeName)),
              selected: selected == c.code,
              onSelected: (_) => onSelected(c.code),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
