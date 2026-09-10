import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/app_notification.dart';

class NotificationsFeed {
  const NotificationsFeed({required this.items, required this.unreadCount});
  final List<AppNotification> items;
  final int unreadCount;

  static const empty = NotificationsFeed(items: [], unreadCount: 0);
}

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<NotificationsFeed> feed() async {
    final data = await _api.get('/api/notifications') as Map;
    final items = ((data['items'] as List?) ?? [])
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return NotificationsFeed(
      items: items,
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Mark one notification read, or all of them when [id] is null.
  Future<void> markRead({String? id}) =>
      _api.post('/api/notifications/read', body: id == null ? const {} : {'id': id});
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(apiClientProvider)),
);

/// Polls the feed every 20 s so the bell badge stays roughly current. A
/// single failed fetch (a network blip, a transient 5xx, a not-yet-verified
/// account) must not permanently kill the polling loop — an uncaught throw
/// inside an async* generator ends the stream for good, so every fetch here
/// is guarded to keep the loop alive, same as `orderMessagesProvider` in
/// chat_repository.dart.
final notificationsProvider = StreamProvider<NotificationsFeed>((ref) async* {
  final repo = ref.watch(notificationsRepositoryProvider);
  NotificationsFeed? last;
  Future<void> fetch() async {
    try {
      last = await repo.feed();
    } catch (_) {
      // keep showing the previous value; the next poll tries again
    }
  }

  await fetch();
  if (last != null) yield last!;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 20))) {
    await fetch();
    if (last != null) yield last!;
  }
});

final notificationUnreadProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).valueOrNull?.unreadCount ?? 0;
});
