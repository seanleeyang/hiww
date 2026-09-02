import 'package:flutter/material.dart';

import '../../../ui/empty_state.dart';

/// D5 replaces this with the real polling chat.
class OrderChatPlaceholder extends StatelessWidget {
  const OrderChatPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Messaging is coming soon',
        message: 'You will be able to chat with the other party about this order '
            'in the next update.',
      ),
    );
  }
}
