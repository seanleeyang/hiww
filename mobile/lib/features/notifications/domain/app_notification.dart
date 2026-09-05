import '../../../core/format.dart';

/// One row in the bell feed. `type` is the backend event kind; `link` is the
/// in-app path to open on tap (usually `/orders/<id>`).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.subject,
    required this.body,
    required this.createdAt,
    this.orderId,
    this.link,
    this.readAt,
  });

  final String id;
  final String type;
  final String subject;
  final String body;
  final DateTime? createdAt;
  final String? orderId;
  final String? link;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'].toString(),
        type: (j['type'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        createdAt: parseDate(j['created_at']),
        orderId: j['order_id']?.toString(),
        link: (j['link'] as String?)?.trim().isEmpty ?? true ? null : j['link'] as String,
        readAt: parseDate(j['read_at']),
      );
}
