import '../../../core/format.dart';
import '../../shared/domain/user_summary.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.body,
    this.createdAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime? createdAt;
  final DateTime? readAt;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'].toString(),
        senderId: j['sender_id'].toString(),
        senderName: (j['sender_name'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        createdAt: parseDate(j['created_at']),
        readAt: parseDate(j['read_at']),
      );
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
