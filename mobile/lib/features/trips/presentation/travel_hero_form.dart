import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cities.dart';
import '../../../l10n/app_localizations.dart';
import 'date_range_sheet.dart';
import 'location_search_sheet.dart';
import 'new_trip_screen.dart';

/// The Travel tab's hero: greeting + a quick from/to/dates card that jumps
/// straight into the full "Post a trip" form pre-filled, instead of a bare
/// CTA button — modelled after a competitor's home screen (screenshots
/// supplied by the user).
class TravelHeroForm extends ConsumerStatefulWidget {
  const TravelHeroForm({
    super.key,
    required this.greeting,
    required this.background,
    required this.foreground,
  });

  final String greeting;
  final Color background;
  final Color foreground;

  @override
  ConsumerState<TravelHeroForm> createState() => _TravelHeroFormState();
}

class _TravelHeroFormState extends ConsumerState<TravelHeroForm> {
  CityOption? _from;
  CityOption? _to;
  DateTime? _depart;
  DateTime? _ret;

  Future<void> _pickFrom() async {
    final picked = await showLocationSearchSheet(context);
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showLocationSearchSheet(context);
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangeSheet(context, initialStart: _depart, initialEnd: _ret);
    if (picked == null) return;
    final (start, end) = picked;
    setState(() {
      _depart = start;
      _ret = end;
    });
  }

  void _add() {
    final from = _from;
    final to = _to;
    final depart = _depart;
    final ret = _ret;
    if (from == null || to == null || depart == null || ret == null) return;
    context.push(
      '/trips/new',
      extra: TripQuickPrefill(
        fromCountry: from.countryCode,
        fromCity: from.city,
        toCountry: to.countryCode,
        toCity: to.city,
        depart: depart,
        ret: ret,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canAdd = _from != null && _to != null && _depart != null && _ret != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      color: widget.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.greeting,
            style: TextStyle(
              color: widget.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.heroTravelFormHeading,
            style: TextStyle(
              color: widget.foreground.withValues(alpha: 0.95),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _FormRow(
            label: l10n.labelTravelingFrom,
            value: _from?.label,
            onTap: _pickFrom,
          ),
          const Divider(height: 1, color: Colors.white24),
          _FormRow(
            label: l10n.labelTravelingTo,
            value: _to?.label,
            onTap: _pickTo,
          ),
          const Divider(height: 1, color: Colors.white24),
          _FormRow(
            label: l10n.labelTravelDates,
            value: (_depart != null && _ret != null)
                ? '${_short(_depart!)} – ${_short(_ret!)}'
                : null,
            onTap: _pickDates,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canAdd ? _add : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                foregroundColor: widget.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(l10n.actionAdd, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(DateTime d) => '${d.month}/${d.day}';
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.value, required this.onTap});
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: TextStyle(
                  color: value != null ? Colors.white : Colors.white70,
                  fontSize: 15,
                  fontWeight: value != null ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
