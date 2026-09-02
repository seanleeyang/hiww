import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/chat/domain/message.dart';

void main() {
  test('Message parses a full row', () {
    final m = Message.fromJson({
      'id': 'm1',
      'sender_id': 'u1',
      'sender_name': 'Nuch S',
      'body': 'Bought it today, shipping tomorrow.',
      'created_at': '2026-11-14T09:30:00.000Z',
      'read_at': null,
    });
    expect(m.senderName, 'Nuch S');
    expect(m.body, contains('shipping'));
    expect(m.createdAt, isNotNull);
    expect(m.readAt, isNull);
  });

  test('InboxThread parses counterparty + unread + last message', () {
    final t = InboxThread.fromJson({
      'order_id': 'ord1',
      'item_description': 'Dyson Airwrap',
      'order_status': 'confirmed',
      'counterparty': {'id': 'u2', 'full_name': 'Mika K', 'rating_avg': 4.7},
      'last_message': {
        'id': 'm2',
        'sender_id': 'u2',
        'body': 'Any update?',
        'created_at': '2026-11-14T10:00:00.000Z',
      },
      'unread_count': 2,
    });
    expect(t.counterparty!.fullName, 'Mika K');
    expect(t.unreadCount, 2);
    expect(t.lastMessage!.body, 'Any update?');
    expect(t.lastMessage!.senderName, ''); // inbox last_message has no name
  });
}
