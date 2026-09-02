import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum _Tone { neutral, positive, warning, danger }

/// Small pill for a backend status string (kyc_status, order status, offer …).
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.icon});

  final String status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hiww = context.hiww;

    final tone = switch (status) {
      'approved' || 'confirmed' || 'delivered' || 'accepted' || 'clear' =>
        _Tone.positive,
      'pending' || 'pending_payment' || 'open' || 'in_transit' || 'in_review' =>
        _Tone.warning,
      'rejected' || 'flagged' || 'restricted' || 'cancelled' || 'closed' =>
        _Tone.danger,
      _ => _Tone.neutral,
    };

    final (Color bg, Color fg) = switch (tone) {
      _Tone.positive => (hiww.successSurface, hiww.success),
      _Tone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _Tone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      _Tone.neutral => (scheme.surfaceContainerHigh, scheme.onSurfaceVariant),
    };

    final label = switch (status) {
      'pending_payment' => 'awaiting payment',
      'in_transit' => 'shipped',
      _ => status.replaceAll('_', ' '),
    };

    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 4, 10, 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
