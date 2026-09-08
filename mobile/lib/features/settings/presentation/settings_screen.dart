import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/section_header.dart';
import '../../../ui/soft_card.dart';
import '../locale_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: const [_LanguageCard()],
      ),
    );
  }
}

/// English/Thai switcher. `null` selection means "follow the system locale",
/// but once someone picks one explicitly it's persisted via
/// [localeControllerProvider] and used regardless of device language.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final chosen = ref.watch(localeControllerProvider).valueOrNull;
    final current = chosen?.languageCode ?? Localizations.localeOf(context).languageCode;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(l10n.settingsLanguage),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(value: 'th', label: Text(l10n.languageThai)),
            ],
            selected: {current == 'th' ? 'th' : 'en'},
            onSelectionChanged: (s) =>
                ref.read(localeControllerProvider.notifier).setLocale(Locale(s.first)),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}
