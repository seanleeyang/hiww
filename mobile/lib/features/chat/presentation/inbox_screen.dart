import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/initials_avatar.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../data/chat_repository.dart';

/// Two sub-tabs: order-scoped chat threads, and account notifications —
/// previously two separate bottom-nav destinations, now one.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.inboxTabMessages),
            Tab(text: l10n.inboxTabNotifications),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [_MessagesTab(), NotificationsScreen()],
          ),
        ),
      ],
    );
  }
}

class _MessagesTab extends ConsumerWidget {
  const _MessagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final inbox = ref.watch(inboxProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.pullToRefresh(inboxProvider.future),
      child: AsyncValueView(
        value: inbox,
        onRetry: () => ref.invalidate(inboxProvider),
        data: (threads) {
          if (threads.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 90),
              EmptyState(
                icon: Icons.forum_outlined,
                title: l10n.emptyInboxTitle,
                message: l10n.emptyInboxMessage,
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
            itemBuilder: (context, i) {
              final t = threads[i];
              final unread = t.unreadCount > 0;
              return ListTile(
                onTap: () => context.push('/orders/${t.orderId}/chat'),
                leading: InitialsAvatar(
                  name: t.counterparty?.fullName ?? '?',
                  url: t.counterparty?.avatarUrl,
                  radius: 22,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.counterparty?.fullName ?? l10n.fallbackConversation,
                        style: TextStyle(
                            fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                      ),
                    ),
                    if (t.lastMessage?.createdAt != null)
                      Text(shortDate(t.lastMessage!.createdAt),
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.itemDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(
                      t.lastMessage?.body ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? scheme.onSurface : scheme.onSurfaceVariant,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                trailing: unread
                    ? Badge(label: Text('${t.unreadCount}'))
                    : null,
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}
