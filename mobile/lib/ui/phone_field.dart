import 'package:flutter/material.dart';

import '../core/world_countries.dart';

/// A phone number split into a dial-code picker + local number field, so
/// entering an area code doesn't require typing "+66" from memory. Composes
/// back into one string (e.g. "+66 81 234 5678") since the backend still
/// stores a single `phone` column.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.value,
    required this.onChanged,
    this.defaultCountryCode,
  });

  /// The full composed value, e.g. "+66 81 234 5678" (or empty).
  final String value;
  final ValueChanged<String> onChanged;

  /// ISO country code to default the dial code to when [value] is empty
  /// (e.g. whatever the address country field is already set to).
  final String? defaultCountryCode;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late String? _dial = _guessDial();
  late final _local = TextEditingController(text: _guessLocal());

  String? _guessDial() {
    final v = widget.value.trim();
    if (v.startsWith('+')) {
      String? best;
      for (final c in kWorldCountries) {
        if (v.startsWith(c.dial) && (best == null || c.dial.length > best.length)) {
          best = c.dial;
        }
      }
      if (best != null) return best;
    }
    return dialCodeFor(widget.defaultCountryCode);
  }

  String _guessLocal() {
    final v = widget.value.trim();
    final dial = _dial;
    if (dial != null && v.startsWith(dial)) return v.substring(dial.length).trim();
    return v;
  }

  void _emit() {
    final local = _local.text.trim();
    final dial = _dial;
    widget.onChanged(dial == null || local.isEmpty ? local : '$dial $local');
  }

  Future<void> _pickDial() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _DialCodeSearchDialog(selected: _dial),
    );
    if (picked != null) {
      setState(() => _dial = picked);
      _emit();
    }
  }

  @override
  void dispose() {
    _local.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: InkWell(
            onTap: _pickDial,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Code'),
              child: Text(_dial ?? 'Select'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _local,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '81 234 5678',
            ),
            onChanged: (_) => _emit(),
          ),
        ),
      ],
    );
  }
}

class _DialCodeSearchDialog extends StatefulWidget {
  const _DialCodeSearchDialog({this.selected});
  final String? selected;

  @override
  State<_DialCodeSearchDialog> createState() => _DialCodeSearchDialogState();
}

class _DialCodeSearchDialogState extends State<_DialCodeSearchDialog> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final results = q.isEmpty
        ? kWorldCountries
        : kWorldCountries
            .where((c) => c.name.toLowerCase().contains(q) || c.dial.contains(q))
            .toList();

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
                  hintText: 'Search country or code',
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
                          leading: SizedBox(
                            width: 48,
                            child: Text(c.dial, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          title: Text(c.name),
                          selected: c.dial == widget.selected,
                          onTap: () => Navigator.of(context).pop(c.dial),
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
