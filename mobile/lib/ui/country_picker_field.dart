import 'package:flutter/material.dart';

import '../core/world_countries.dart';

/// A form-field-styled tappable box that opens a searchable country picker.
/// Used where a value must be one of `kWorldCountries` (e.g. a delivery
/// address) rather than free text, so the stored value is a standardised
/// ISO code.
class CountryPickerField extends StatelessWidget {
  const CountryPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Country',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _CountrySearchDialog(selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final name = worldCountryName(value);
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.arrow_drop_down)),
        child: Text(
          name.isEmpty ? 'Select a country' : name,
          style: name.isEmpty
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

class _CountrySearchDialog extends StatefulWidget {
  const _CountrySearchDialog({this.selected});
  final String? selected;

  @override
  State<_CountrySearchDialog> createState() => _CountrySearchDialogState();
}

class _CountrySearchDialogState extends State<_CountrySearchDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final matches = q.isEmpty
        ? kWorldCountries
        : kWorldCountries.where((c) => c.name.toLowerCase().contains(q)).toList();
    // Thailand first — this is a Thailand-based pilot, so it's who almost
    // everyone is picking, and it's otherwise buried mid-alphabet. Same
    // reasoning as the phone dial-code picker (phone_field.dart).
    final results = [
      ...matches.where((c) => c.code == 'TH'),
      ...matches.where((c) => c.code != 'TH'),
    ];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 480, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search countries',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Flexible(
              child: results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matches'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return ListTile(
                          title: Text(c.name),
                          selected: c.code == widget.selected,
                          onTap: () => Navigator.of(context).pop(c.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
