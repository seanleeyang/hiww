import 'package:flutter/material.dart';

/// Category vocabulary shared by Browse filters and the Post Want sheet.
/// `null` value = "All" (filter only).
const kCategories = <({String? value, String label})>[
  (value: null, label: 'All'),
  (value: 'beauty', label: 'Beauty'),
  (value: 'fashion', label: 'Fashion'),
  (value: 'sneakers', label: 'Sneakers'),
  (value: 'electronics', label: 'Electronics'),
  (value: 'snacks', label: 'Snacks'),
  (value: 'other', label: 'Others'),
];

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
    final options =
        includeAll ? kCategories : kCategories.where((c) => c.value != null).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final c in options) ...[
            ChoiceChip(
              label: Text(c.label),
              selected: selected == c.value,
              onSelected: (_) => onSelected(c.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
