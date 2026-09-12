import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cities.dart';
import '../../../core/storage/recent_locations_storage.dart';
import '../../../l10n/app_localizations.dart';

/// A near-full-height bottom sheet: search field + recent/matching cities.
/// Returns the picked [CityOption], or null if dismissed without a pick.
Future<CityOption?> showLocationSearchSheet(BuildContext context) {
  return showModalBottomSheet<CityOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _LocationSearchSheet(),
  );
}

class _LocationSearchSheet extends ConsumerStatefulWidget {
  const _LocationSearchSheet();

  @override
  ConsumerState<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends ConsumerState<_LocationSearchSheet> {
  final _query = TextEditingController();
  List<CityOption> _results = kCities;
  List<String> _recents = const [];

  @override
  void initState() {
    super.initState();
    ref.read(recentLocationsStorageProvider).read().then((r) {
      if (mounted) setState(() => _recents = r);
    });
    _query.addListener(() => setState(() => _results = searchCities(_query.text)));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _pick(CityOption c) async {
    await ref.read(recentLocationsStorageProvider).add(c.city);
    if (mounted) Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final showingRecents = _query.text.isEmpty && _recents.isNotEmpty;
    final recentCities = _recents
        .map((name) => kCities.where((c) => c.city == name).firstOrNull)
        .whereType<CityOption>()
        .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.92,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    l10n.locationSearchTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.fieldCity,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (showingRecents) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      l10n.locationRecentSection,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  for (final c in recentCities)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(c.cityLabel(l10n.localeName)),
                      subtitle: Text(c.countryLabel(l10n.localeName)),
                      onTap: () => _pick(c),
                    ),
                  const Divider(height: 24),
                ],
                for (final c in _results)
                  ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text(c.cityLabel(l10n.localeName)),
                    subtitle: Text(c.countryLabel(l10n.localeName)),
                    onTap: () => _pick(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
