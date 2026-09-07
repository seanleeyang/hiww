import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ui/brand_mark.dart';
import '../../ui/initials_avatar.dart';
import '../auth/application/auth_controller.dart';
import '../auth/domain/auth_user.dart';
import '../chat/data/chat_repository.dart';
import '../notifications/data/notifications_repository.dart';

enum ShellTab {
  browse('/browse', 'Browse', Icons.travel_explore_outlined, Icons.travel_explore),
  trips('/my-trips', 'My Trips', Icons.flight_outlined, Icons.flight),
  wants('/my-wants', 'My Wants', Icons.favorite_outline, Icons.favorite),
  offers('/offers', 'Offers', Icons.handshake_outlined, Icons.handshake),
  orders('/my-orders', 'Orders', Icons.receipt_long_outlined, Icons.receipt_long),
  inbox('/inbox', 'Inbox', Icons.forum_outlined, Icons.forum);

  const ShellTab(this.path, this.label, this.icon, this.activeIcon);

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  bool visibleTo(UserType type) => switch (this) {
        ShellTab.trips => type.isTraveler,
        ShellTab.wants => type.isShopper,
        _ => true,
      };
}

/// App chrome for the signed-in tabs: a branded app bar with the account
/// avatar, and a responsive nav rail / bottom bar.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final type = user?.userType ?? UserType.both;
    final tabs = ShellTab.values.where((t) => t.visibleTo(type)).toList();

    var index = tabs.indexWhere((t) => location.startsWith(t.path));
    if (index < 0) index = 0;

    void go(int i) => context.go(tabs[i].path);

    final unread = ref.watch(unreadTotalProvider);
    Widget tabIcon(ShellTab t, {required bool selected}) {
      final icon = Icon(selected ? t.activeIcon : t.icon);
      if (t == ShellTab.inbox && unread > 0) {
        return Badge(label: Text('$unread'), child: icon);
      }
      return icon;
    }

    final wide = MediaQuery.sizeOf(context).width >= 760;

    final notifUnread = ref.watch(notificationUnreadProvider);

    final appBar = AppBar(
      title: const BrandMark(),
      titleSpacing: 16,
      actions: [
        Tooltip(
          message: 'Notifications',
          child: IconButton(
            onPressed: () => context.push('/notifications'),
            icon: notifUnread > 0
                ? Badge(
                    label: Text('$notifUnread'),
                    child: const Icon(Icons.notifications_none),
                  )
                : const Icon(Icons.notifications_none),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Tooltip(
            message: 'Account',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => context.go('/account'),
              child: Semantics(
                button: true,
                label: 'Account',
                child: InitialsAvatar(
                  name: user?.fullName ?? 'Hiww',
                  url: user?.avatarUrl,
                  radius: 17,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final t in tabs)
                  NavigationRailDestination(
                    icon: tabIcon(t, selected: false),
                    selectedIcon: tabIcon(t, selected: true),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: tabIcon(t, selected: false),
              selectedIcon: tabIcon(t, selected: true),
              label: t.label,
            ),
        ],
      ),
    );
  }
}
