import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/brand_mark.dart';
import '../../ui/initials_avatar.dart';
import '../../ui/language_toggle.dart';
import '../auth/application/auth_controller.dart';
import '../chat/data/chat_repository.dart';
import '../notifications/data/notifications_repository.dart';

/// Four tabs, always shown to everyone regardless of shopper/traveler role
/// (unlike the old 6-tab layout, where "My Trips"/"My Wants" only appeared
/// for the matching role) — a pure shopper still sees an empty Trips tab
/// with an "Add trip" prompt, in case they want to try traveling too.
enum ShellTab {
  home('/browse', Icons.home_outlined, Icons.home),
  orders('/my-orders', Icons.shopping_bag_outlined, Icons.shopping_bag),
  trips('/my-trips', Icons.flight_outlined, Icons.flight),
  inbox('/inbox', Icons.forum_outlined, Icons.forum);

  const ShellTab(this.path, this.icon, this.activeIcon);

  final String path;
  final IconData icon;
  final IconData activeIcon;

  String labelFor(AppLocalizations l10n) => switch (this) {
        ShellTab.home => l10n.tabBrowse,
        ShellTab.orders => l10n.tabOrders,
        ShellTab.trips => l10n.tabMyTrips,
        ShellTab.inbox => l10n.tabInbox,
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
    const tabs = ShellTab.values;

    var index = tabs.indexWhere((t) => location.startsWith(t.path));
    if (index < 0) index = 0;

    void go(int i) => context.go(tabs[i].path);

    // Inbox's badge now covers both sub-tabs it hosts (Messages +
    // Notifications) — the app bar no longer has its own separate bell, so
    // this is the only place either kind of unread count surfaces.
    final unread = ref.watch(unreadTotalProvider) + ref.watch(notificationUnreadProvider);
    Widget tabIcon(ShellTab t, {required bool selected}) {
      final icon = Icon(selected ? t.activeIcon : t.icon);
      if (t == ShellTab.inbox && unread > 0) {
        return Badge(label: Text('$unread'), child: icon);
      }
      return icon;
    }

    final wide = MediaQuery.sizeOf(context).width >= 760;

    final l10n = AppLocalizations.of(context)!;
    final signedIn = user != null;

    final appBar = AppBar(
      title: const BrandMark(),
      titleSpacing: 16,
      actions: [
        const Padding(
          padding: EdgeInsets.only(right: 12),
          child: LanguageToggle(),
        ),
        if (signedIn)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: l10n.tooltipAccount,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => context.go('/account'),
                child: Semantics(
                  button: true,
                  label: l10n.tooltipAccount,
                  child: InitialsAvatar(
                    name: user.fullName,
                    url: user.avatarUrl,
                    radius: 17,
                  ),
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => context.push('/landing'),
              child: Text(l10n.actionLogIn),
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
                    label: Text(t.labelFor(l10n)),
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
              label: t.labelFor(l10n),
            ),
        ],
      ),
    );
  }
}
