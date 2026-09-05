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

/// Polls the feed every 20 s so the bell badge stays roughly current.
final notificationsProvider = StreamProvider<NotificationsFeed>((ref) async* {
  final repo = ref.watch(notificationsRepositoryProvider);
  yield await repo.feed();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 20))) {
    yield await repo.feed();
  }
});

final notificationUnreadProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).valueOrNull?.unreadCount ?? 0;
});
