import 'package:flutter/material.dart';

import '../core/thai_geography.dart';

/// Cascading Province → District → Sub-district picker for a Thai address,
/// backed by the bundled Thai geography dataset. Selecting a sub-district
/// auto-fills the postal code (all three levels share one postal-code
/// column in the source data, so the result is unambiguous once a
/// sub-district is chosen).
///
/// Values are passed and returned as plain English names — the same strings
/// the backend already stores in `address_city`/`address_district`/
/// `address_subdistrict`/`address_postal_code` — so no new column or code
/// scheme is needed on the server side.
class ThaiAddressPicker extends StatefulWidget {
  const ThaiAddressPicker({
    super.key,
    required this.province,
    required this.district,
    required this.subdistrict,
    required this.postalCode,
    required this.onChanged,
    this.provinceLabel = 'Province',
    this.districtLabel = 'District',
    this.subdistrictLabel = 'Sub-district',
    this.postalCodeLabel = 'Postal code',
  });

  final String province;
  final String district;
  final String subdistrict;
  final String postalCode;
  final void Function({
    required String province,
    required String district,
    required String subdistrict,
    required String postalCode,
  }) onChanged;
  final String provinceLabel;
  final String districtLabel;
  final String subdistrictLabel;
  final String postalCodeLabel;

  @override
  State<ThaiAddressPicker> createState() => _ThaiAddressPickerState();
}

class _ThaiAddressPickerState extends State<ThaiAddressPicker> {
  final Future<ThaiGeography> _future = ThaiGeography.load();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ThaiGeography>(
      future: _future,
      builder: (context, snapshot) {
        final geo = snapshot.data;
        if (geo == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final province = geo.provinceByName(widget.province);
        final district = province == null ? null : geo.districtByName(province.code, widget.district);
        final subdistrict =
            district == null ? null : geo.subdistrictByName(district.code, widget.subdistrict);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PickerRow(
              label: widget.provinceLabel,
              value: province?.nameEn,
              onTap: () async {
                final picked = await showDialog<ThaiProvince>(
                  context: context,
                  builder: (_) => _SearchDialog<ThaiProvince>(
                    items: geo.provinces,
                    selected: province,
                    labelOf: (p) => p.nameEn,
                    subLabelOf: (p) => p.nameTh,
                  ),
                );
                if (picked == null) return;
                widget.onChanged(
                  province: picked.nameEn,
                  district: '',
                  subdistrict: '',
                  postalCode: '',
                );
              },
            ),
            const SizedBox(height: 12),
            _PickerRow(
              label: widget.districtLabel,
              value: district?.nameEn,
              enabled: province != null,
              onTap: province == null
                  ? null
                  : () async {
                      final picked = await showDialog<ThaiDistrict>(
                        context: context,
                        builder: (_) => _SearchDialog<ThaiDistrict>(
                          items: geo.districtsFor(province.code),
                          selected: district,
                          labelOf: (d) => d.nameEn,
                          subLabelOf: (d) => d.nameTh,
                        ),
                      );
                      if (picked == null) return;
                      widget.onChanged(
                        province: province.nameEn,
                        district: picked.nameEn,
                        subdistrict: '',
                        postalCode: '',
                      );
                    },
            ),
            const SizedBox(height: 12),
            _PickerRow(
              label: widget.subdistrictLabel,
              value: subdistrict?.nameEn,
              enabled: district != null,
              onTap: district == null
                  ? null
                  : () async {
                      final picked = await showDialog<ThaiSubdistrict>(
                        context: context,
                        builder: (_) => _SearchDialog<ThaiSubdistrict>(
                          items: geo.subdistrictsFor(district.code),
                          selected: subdistrict,
                          labelOf: (s) => s.nameEn,
                          subLabelOf: (s) => s.nameTh,
                        ),
                      );
                      if (picked == null) return;
                      widget.onChanged(
                        province: province!.nameEn,
                        district: district.nameEn,
                        subdistrict: picked.nameEn,
                        postalCode: picked.postalCode,
                      );
                    },
            ),
            const SizedBox(height: 12),
            _PickerRow(
              label: widget.postalCodeLabel,
              value: widget.postalCode.isEmpty ? null : widget.postalCode,
              enabled: district != null,
              // Picking a sub-district already auto-fills the postal code
              // it's officially assigned (see the class doc comment) — this
              // is only for the rarer case of overriding it (e.g. a large
              // organization with its own dedicated code) once a district
              // narrows down which codes are even plausible.
              onTap: district == null
                  ? null
                  : () async {
                      final codes = geo
                          .subdistrictsFor(district.code)
                          .map((s) => s.postalCode)
                          .toSet()
                          .toList()
                        ..sort();
                      final picked = await showDialog<String>(
                        context: context,
                        builder: (_) => _SearchDialog<String>(
                          items: codes,
                          selected: widget.postalCode.isEmpty ? null : widget.postalCode,
                          labelOf: (c) => c,
                          subLabelOf: (_) => '',
                        ),
                      );
                      if (picked == null) return;
                      widget.onChanged(
                        province: province!.nameEn,
                        district: district.nameEn,
                        subdistrict: widget.subdistrict,
                        postalCode: picked,
                      );
                    },
            ),
          ],
        );
      },
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: enabled,
        ),
        child: Text(
          value ?? 'Select',
          style: value == null
              ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  const _SearchDialog({
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.subLabelOf,
  });

  final List<T> items;
  final T? selected;
  final String Function(T) labelOf;
  final String Function(T) subLabelOf;

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
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
        ? widget.items
        : widget.items
            .where((i) =>
                widget.labelOf(i).toLowerCase().contains(q) || widget.subLabelOf(i).contains(q))
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
                  hintText: 'Search',
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
                        final item = results[i];
                        return ListTile(
                          title: Text(widget.labelOf(item)),
                          subtitle: Text(widget.subLabelOf(item)),
                          selected: widget.selected != null &&
                              widget.labelOf(item) == widget.labelOf(widget.selected as T),
                          onTap: () => Navigator.of(context).pop(item),
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
