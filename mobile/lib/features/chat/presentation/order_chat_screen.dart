import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/format.dart';
import '../../../l10n/app_localizations.dart';
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
  bool _deletingChat = false;
  Uint8List? _pendingImageBytes;
  String? _pendingImageUrl;
  int _lastSeenCount = -1;
  DateTime? _lastTypingPing;

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

  /// Throttled to at most once every 2 s while actively typing — matches
  /// the server's typing-heartbeat TTL closely enough without pinging on
  /// every keystroke.
  void _onComposerChanged(String _) {
    final now = DateTime.now();
    if (_lastTypingPing != null &&
        now.difference(_lastTypingPing!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingPing = now;
    ref.read(chatRepositoryProvider).sendTyping(widget.orderId);
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
    final l10n = AppLocalizations.of(context)!;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.errorAttachPhoto)));
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

  Future<void> _deleteChat() async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dialogDeleteChatTitle),
        content: Text(l10n.dialogDeleteChatBody),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.actionDeleteChat),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.actionCancel),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deletingChat = true);
    try {
      await ref.read(chatRepositoryProvider).deleteChat(widget.orderId);
      ref.invalidate(orderMessagesProvider(widget.orderId));
      ref.invalidate(inboxProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _deletingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final me = ref.watch(currentUserProvider);
    final order = ref.watch(orderProvider(widget.orderId));
    final feed = ref.watch(orderMessagesProvider(widget.orderId));
    final feedValue = feed.valueOrNull;
    final closed = feedValue?.closed ?? false;
    final deleted = feedValue?.deleted ?? false;

    // Mark read whenever new inbound messages land.
    ref.listen(orderMessagesProvider(widget.orderId), (_, next) {
      final list = next.valueOrNull?.messages;
      if (list == null) return;
      if (list.length != _lastSeenCount) {
        _lastSeenCount = list.length;
        if (list.any((m) => m.senderId != me?.id && m.readAt == null)) {
          _markRead();
        }
      }
    });

    final title =
        order.valueOrNull?.counterparty?.fullName ?? l10n.chatFallbackTitle;
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
        actions: [
          if (closed && !deleted)
            IconButton(
              tooltip: l10n.actionDeleteChat,
              onPressed: _deletingChat ? null : _deleteChat,
              icon: _deletingChat
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          if (closed && !deleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Text(
                l10n.chatClosedBanner,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Expanded(
            child: AsyncValueView(
              value: feed,
              onRetry: () =>
                  ref.invalidate(orderMessagesProvider(widget.orderId)),
              data: (chatFeed) {
                if (chatFeed.deleted) {
                  return Center(
                    child: Text(
                      l10n.chatDeletedMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final list = chatFeed.messages;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.sayHello,
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
                    final mine = m.senderId == me?.id;
                    return _Bubble(
                      message: m,
                      mine: mine,
                      showStatus: i == 0 && mine,
                    );
                  },
                );
              },
            ),
          ),
          if (feed.valueOrNull?.counterpartyTyping ?? false)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TypingBubble(),
              ),
            ),
          if (!closed)
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
              onTextChanged: _onComposerChanged,
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    this.showStatus = false,
  });
  final Message message;
  final bool mine;

  /// Show a "Sent"/"Read" line under this bubble — only the latest message
  /// the current user sent, matching the usual chat-app convention.
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    chatTimestamp(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: (mine ? scheme.onPrimary : scheme.onSurfaceVariant)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                  if (showStatus) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.readAt != null ? Icons.done_all : Icons.done,
                      size: 13,
                      color: (message.readAt != null
                          ? scheme.onPrimary
                          : scheme.onPrimary.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      message.readAt != null
                          ? l10n.statusRead
                          : l10n.statusSent,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ],
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
    required this.onTextChanged,
  });

  final TextEditingController controller;
  final bool sending;
  final bool attaching;
  final Uint8List? pendingImageBytes;
  final VoidCallback onAttach;
  final VoidCallback onRemoveAttachment;
  final VoidCallback onSend;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = sending || attaching;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingImageBytes != null) ...[
              // A clearly-labelled staging banner, not a floating thumbnail —
              // easy to mistake the bare thumbnail for an already-sent
              // message otherwise.
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            pendingImageBytes!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (attaching)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.35),
                                child: const Center(
                                  child: SizedBox(
                                    height: 14,
                                    width: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        attaching
                            ? l10n.uploadingPhoto
                            : l10n.photoAttachedTapSend,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onRemoveAttachment,
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: l10n.tooltipRemovePhoto,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                IconButton(
                  onPressed: busy ? null : onAttach,
                  tooltip: l10n.tooltipAttachPhoto,
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
                    onChanged: onTextChanged,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: l10n.hintMessage,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: busy ? null : onSend,
                  tooltip: l10n.tooltipSend,
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

/// Three pulsing dots, styled like the counterparty's message bubbles —
/// shown while `ChatFeed.counterpartyTyping` is true.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SizedBox(
        width: 30,
        height: 8,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(3, (i) {
                final phase = (_controller.value + i * 0.25) % 1.0;
                final bounce = (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);
                return Opacity(
                  opacity: 0.35 + 0.65 * bounce,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
