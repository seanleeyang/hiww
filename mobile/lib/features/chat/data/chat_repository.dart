import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/format.dart';
import '../domain/message.dart';

class ChatRepository {
  ChatRepository(this._api);
  final ApiClient _api;

  Future<ChatFeed> feed(String orderId) async {
    final data = await _api.get('/api/orders/$orderId/messages');
    final map = data as Map;
    final items = (map['items'] as List?) ?? [];
    // One malformed row must not take down the whole conversation — parse
    // defensively and skip anything that doesn't fit, rather than letting
    // the exception propagate and silently killing the polling stream.
    final parsed = <Message>[];
    for (final e in items) {
      try {
        parsed.add(Message.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        // skip malformed row
      }
    }
    return ChatFeed(
      messages: parsed,
      counterpartyTyping: map['counterparty_typing'] == true,
      closed: map['closed'] == true,
      deleted: map['deleted'] == true,
      closesAt: parseDate(map['closes_at']),
    );
  }

  /// Best-effort heartbeat while composing — the counterparty picks it up on
  /// their next poll. A missed ping just means the indicator flickers off a
  /// touch early; never worth surfacing an error for.
  Future<void> sendTyping(String orderId) async {
    try {
      await _api.post('/api/orders/$orderId/typing');
    } catch (_) {
      // best-effort
    }
  }

  /// Returns a safety-warning string when the message (or its photo) tripped
  /// the leakage/QR check — a flagged text message still sends either way; a
  /// flagged photo is dropped server-side but any caption text still sends.
  /// The caller decides how to surface the warning. At least one of [body]
  /// or [imageUrl] must be non-empty.
  Future<String?> send(String orderId, {String? body, String? imageUrl}) async {
    final data = await _api.post(
      '/api/orders/$orderId/messages',
      body: {
        if (body != null && body.isNotEmpty) 'body': body,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      },
    );
    final warning = (data as Map)['warning'];
    return warning is String ? warning : null;
  }

  Future<void> markRead(String orderId) =>
      _api.post('/api/orders/$orderId/messages/read');

  /// Hides this (closed) chat from the caller's own inbox/view — the
  /// counterparty's copy and the underlying messages are untouched. Throws
  /// [ApiException] if the order isn't delivered yet.
  Future<void> deleteChat(String orderId) =>
      _api.post('/api/orders/$orderId/messages/delete-chat');

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

/// Polls the inbox every 15 s so the nav badge stays roughly current. A
/// single failed fetch (a network blip, a transient 5xx, a not-yet-verified
/// account) must not permanently kill the polling loop — an uncaught throw
/// inside an async* generator ends the stream for good, so every fetch here
/// is guarded to keep the loop alive, same as `orderMessagesProvider` below.
final inboxProvider = StreamProvider<List<InboxThread>>((ref) async* {
  final repo = ref.watch(chatRepositoryProvider);
  List<InboxThread>? last;
  Future<void> fetch() async {
    try {
      last = await repo.inbox();
    } catch (_) {
      // keep showing the previous value; the next poll tries again
    }
  }

  await fetch();
  if (last != null) yield last!;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
    await fetch();
    if (last != null) yield last!;
  }
});

final unreadTotalProvider = Provider<int>((ref) {
  final inbox = ref.watch(inboxProvider).valueOrNull ?? const [];
  return inbox.fold(0, (sum, t) => sum + t.unreadCount);
});

/// Polls one conversation every 3 s while a chat screen is open — shorter
/// than most polls in this app so the typing indicator stays reasonably
/// responsive (there's no websocket here; this is the tradeoff). A single
/// failed fetch (a network blip, a transient 5xx) must not permanently kill
/// the polling loop — an uncaught throw inside an async* generator ends the
/// stream for good, so every fetch here is guarded to keep the loop alive.
final orderMessagesProvider = StreamProvider.family<ChatFeed, String>((
  ref,
  orderId,
) async* {
  final repo = ref.watch(chatRepositoryProvider);
  ChatFeed? last;
  Future<void> fetch() async {
    try {
      last = await repo.feed(orderId);
    } catch (_) {
      // keep showing the previous value; the next poll tries again
    }
  }

  await fetch();
  if (last != null) yield last!;
  await for (final _ in Stream<void>.periodic(const Duration(seconds: 3))) {
    await fetch();
    if (last != null) yield last!;
  }
});
