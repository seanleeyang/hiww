import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Category vocabulary shared by Browse filters and the Post Want sheet.
/// `null` value = "All" (filter only). `value` is what the backend stores;
/// the display label always comes from [categoryLabel] (localized), never
/// hardcoded English.
const kCategoryValues = <String?>[null, 'beauty', 'fashion', 'sneakers', 'electronics', 'snacks', 'other'];

String categoryLabel(AppLocalizations l10n, String? value) => switch (value) {
      null => l10n.categoryAll,
      'beauty' => l10n.categoryBeauty,
      'fashion' => l10n.categoryFashion,
      'sneakers' => l10n.categorySneakers,
      'electronics' => l10n.categoryElectronics,
      'snacks' => l10n.categorySnacks,
      _ => l10n.categoryOther,
    };

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.includeAll = true,
  });

  final String? selected;
  final ValueChanged<String?> onSelected;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final values = includeAll ? kCategoryValues : kCategoryValues.where((v) => v != null).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final v in values) ...[
            ChoiceChip(
              label: Text(categoryLabel(l10n, v)),
              selected: selected == v,
              onSelected: (_) => onSelected(v),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
