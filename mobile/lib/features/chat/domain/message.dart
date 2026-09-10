import '../../../core/format.dart';
import '../../shared/domain/user_summary.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    this.imageUrl,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'].toString(),
    senderId: j['sender_id'].toString(),
    senderName: (j['sender_name'] ?? '').toString(),
    body: (j['body'] ?? '').toString(),
    imageUrl: (j['image_url'] as String?)?.trim().isEmpty ?? true
        ? null
        : j['image_url'] as String,
    createdAt: parseDate(j['created_at']),
    readAt: parseDate(j['read_at']),
  );
}

/// One poll of a conversation: the messages plus whether the other
/// participant is currently typing.
class ChatFeed {
  const ChatFeed({
    required this.messages,
    required this.counterpartyTyping,
    this.closed = false,
    this.deleted = false,
    this.closesAt,
  });

  final List<Message> messages;
  final bool counterpartyTyping;

  /// The order reached `delivered` or `cancelled` and the 24h grace period
  /// has passed — nothing left to coordinate on, so new messages are rejected.
  final bool closed;

  /// The viewer deleted this (closed) chat from their own view — `messages`
  /// is empty in that case; the counterparty's copy is unaffected.
  final bool deleted;

  /// Set once the order is delivered/cancelled but still within the 24h
  /// grace period — when the chat will actually lock. Null while there's
  /// still an active negotiation/transaction, or once already closed.
  final DateTime? closesAt;
}

class InboxThread {
  const InboxThread({
    required this.orderId,
    required this.itemDescription,
    required this.orderStatus,
    this.counterparty,
    this.lastMessage,
    this.unreadCount = 0,
  });

  final String orderId;
  final String itemDescription;
  final String orderStatus;
  final UserSummary? counterparty;
  final Message? lastMessage;
  final int unreadCount;

  factory InboxThread.fromJson(Map<String, dynamic> j) => InboxThread(
    orderId: j['order_id'].toString(),
    itemDescription: (j['item_description'] ?? '').toString(),
    orderStatus: (j['order_status'] ?? '').toString(),
    counterparty: UserSummary.fromJson(j['counterparty']),
    lastMessage: j['last_message'] is Map
        ? Message.fromJson(Map<String, dynamic>.from(j['last_message'] as Map))
        : null,
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
  );
}
