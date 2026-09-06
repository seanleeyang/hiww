import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/fullscreen_image_viewer.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/data/orders_repository.dart';
import '../../uploads/data/uploads_repository.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';

class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  final _input = TextEditingController();
  bool _sending = false;
  bool _attaching = false;
  Uint8List? _pendingImageBytes;
  String? _pendingImageUrl;
  int _lastSeenCount = -1;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.orderId);
      ref.invalidate(inboxProvider);
    } catch (_) {
      /* best effort */
    }
  }

  Future<void> _attachPhoto() async {
    setState(() => _attaching = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      // Show the picked photo straight from local bytes — no reason to round
      // trip to the network just to preview something already on the device,
      // and it sidesteps the delay before a freshly-uploaded R2 object is
      // reliably readable back (the same lag seen with want/trip photos).
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _pendingImageBytes = bytes);
      final url = await ref.read(uploadsRepositoryProvider).uploadImage(file);
      if (mounted) setState(() => _pendingImageUrl = url);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _pendingImageBytes = null);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _pendingImageBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not attach that photo. Try another.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final imageUrl = _pendingImageUrl;
    if (text.isEmpty && imageUrl == null) return;
    setState(() => _sending = true);
    try {
      final warning = await ref
          .read(chatRepositoryProvider)
          .send(widget.orderId, body: text, imageUrl: imageUrl);
      _input.clear();
      setState(() {
        _pendingImageUrl = null;
        _pendingImageBytes = null;
      });
      ref.invalidate(orderMessagesProvider(widget.orderId));
      ref.invalidate(inboxProvider);
      if (warning != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warning),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final order = ref.watch(orderProvider(widget.orderId));
    final messages = ref.watch(orderMessagesProvider(widget.orderId));

    // Mark read whenever new inbound messages land.
    ref.listen(orderMessagesProvider(widget.orderId), (_, next) {
      final list = next.valueOrNull;
      if (list == null) return;
      if (list.length != _lastSeenCount) {
        _lastSeenCount = list.length;
        if (list.any((m) => m.senderId != me?.id && m.readAt == null)) {
          _markRead();
        }
      }
    });

    final title = order.valueOrNull?.counterparty?.fullName ?? 'Chat';
    final subtitle = order.valueOrNull?.itemDescription;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            if (subtitle != null)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AsyncValueView(
              value: messages,
              onRetry: () =>
                  ref.invalidate(orderMessagesProvider(widget.orderId)),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Say hello 👋',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final m = list[list.length - 1 - i];
                    return _Bubble(message: m, mine: m.senderId == me?.id);
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _input,
            sending: _sending,
            attaching: _attaching,
            pendingImageBytes: _pendingImageBytes,
            onAttach: _attachPhoto,
            onRemoveAttachment: () => setState(() {
              _pendingImageUrl = null;
              _pendingImageBytes = null;
            }),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final Message message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.76,
        ),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null) ...[
              GestureDetector(
                onTap: () => showFullscreenImage(context, message.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: message.imageUrl!,
                    width: double.infinity,
                    height: 260,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      width: double.infinity,
                      height: 260,
                      color: scheme.surfaceContainerHighest,
                    ),
                    errorWidget: (_, _, _) => Container(
                      width: double.infinity,
                      height: 260,
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              if (message.body.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: TextStyle(
                  color: mine ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 3),
              Text(
                shortDate(message.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: (mine ? scheme.onPrimary : scheme.onSurfaceVariant)
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.attaching,
    required this.pendingImageBytes,
    required this.onAttach,
    required this.onRemoveAttachment,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final bool attaching;
  final Uint8List? pendingImageBytes;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final busy = sending || attaching;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingImageBytes != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      pendingImageBytes!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (attaching)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: const Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: -8,
                    right: -8,
                    child: IconButton(
                      onPressed: onRemoveAttachment,
                      icon: const Icon(Icons.cancel, size: 20),
                      color: Theme.of(context).colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: busy ? null : onAttach,
                  tooltip: 'Attach a photo',
                  icon: attaching
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: busy ? null : onSend,
                  tooltip: 'Send',
                  icon: sending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
