import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/message.dart';

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<List<Message>> messages(String orderId) async {
    final data = await _api.get('/api/orders/$orderId/messages');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items.map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> send(String orderId, String body) =>
      _api.post('/api/orders/$orderId/messages', body: {'body': body});

  Future<void> markRead(String orderId) =>
      _api.post('/api/orders/$orderId/messages/read');

  Future<List<InboxThread>> inbox() async {
    final data = await _api.get('/api/inbox');
    final items = ((data as Map)['items'] as List?) ?? [];
    return items
        .map((e) => InboxThread.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(apiClientProvider)),
);

/// Polls the inbox every 15 s so the nav badge stays roughly current.
final inboxProvider = StreamProvider<List<InboxThread>>((ref) async* {
  final repo = ref.watch(chatRepositoryProvider);
  yield await repo.inbox();
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
    yield await repo.inbox();
  }
});

final unreadTotalProvider = Provider<int>((ref) {
  final inbox = ref.watch(inboxProvider).valueOrNull ?? const [];
  return inbox.fold(0, (sum, t) => sum + t.unreadCount);
});

/// Polls one conversation every 5 s while a chat screen is open.
final orderMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, orderId) async* {
  final repo = ref.watch(chatRepositoryProvider);
  yield await repo.messages(orderId);
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 5))) {
    yield await repo.messages(orderId);
  }
});
