import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../data/notifications_repository.dart';

/// Bare content, no own `Scaffold`/`AppBar` — embedded as the Inbox tab's
/// "Notifications" sub-tab, matching `InboxScreen`'s "Messages" sub-tab.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final feed = ref.watch(notificationsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  await ref.read(notificationsRepositoryProvider).markRead();
                  ref.invalidate(notificationsProvider);
                },
                child: Text(l10n.actionMarkAllRead),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.pullToRefresh(notificationsProvider.future),
            child: AsyncValueView(
              value: feed,
              onRetry: () => ref.invalidate(notificationsProvider),
              data: (data) {
                if (data.items.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 90),
                      EmptyState(
                        icon: Icons.notifications_none,
                        title: l10n.notificationsEmptyTitle,
                        message: l10n.notificationsEmptyMessage,
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: data.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 64),
                  itemBuilder: (context, i) {
                    final n = data.items[i];
                    return ListTile(
                      onTap: () async {
                        if (n.isUnread) {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markRead(id: n.id);
                          ref.invalidate(notificationsProvider);
                        }
                        if (!context.mounted) return;
                        final to =
                            n.link ??
                            (n.orderId != null ? '/orders/${n.orderId}' : null);
                        if (to != null) context.push(to);
                      },
                      leading: CircleAvatar(
                        backgroundColor: n.isUnread
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHigh,
                        foregroundColor: n.isUnread
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        child: Icon(_iconFor(n.type), size: 20),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.subject,
                              style: TextStyle(
                                fontWeight: n.isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            timeAgo(n.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          n.body,
                          style: TextStyle(
                            color: n.isUnread
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(String type) => switch (type) {
    'offer_received' => Icons.local_offer_outlined,
    'offer_accepted' => Icons.handshake_outlined,
    'payment_claimed' => Icons.hourglass_top,
    'payment_confirmed' => Icons.payments_outlined,
    'purchase_proof' => Icons.receipt_long_outlined,
    'upload_reminder' => Icons.timer_outlined,
    'shipped' => Icons.local_shipping_outlined,
    'delivered' => Icons.check_circle_outline,
    'payout_due' => Icons.account_balance_wallet_outlined,
    'payout_sent' => Icons.account_balance_wallet_outlined,
    'dispute_opened' => Icons.report_gmailerrorred_outlined,
    'dispute_resolved' => Icons.gavel_outlined,
    'message_flagged' => Icons.flag_outlined,
    'order_cancelled' => Icons.cancel_outlined,
    'refund_due' => Icons.account_balance_wallet_outlined,
    'refund_sent' => Icons.account_balance_wallet_outlined,
    _ => Icons.notifications_none,
  };
}
