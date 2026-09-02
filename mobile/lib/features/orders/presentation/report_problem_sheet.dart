import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../data/disputes_repository.dart';
import '../data/orders_repository.dart';

Future<void> showReportProblemSheet(BuildContext context, String orderId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _ReportProblemSheet(orderId: orderId),
    ),
  );
}

class _ReportProblemSheet extends ConsumerStatefulWidget {
  const _ReportProblemSheet({required this.orderId});
  final String orderId;

  @override
  ConsumerState<_ReportProblemSheet> createState() => _ReportProblemSheetState();
}

class _ReportProblemSheetState extends ConsumerState<_ReportProblemSheet> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason.text.trim().length < 10) {
      setState(() => _error = 'Please describe the problem (at least 10 characters)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(disputesRepositoryProvider)
          .open(widget.orderId, _reason.text.trim());
      ref.invalidate(orderProvider(widget.orderId));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reported — the Hiww team will look into it')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report a problem',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Money stays held while the Hiww team reviews this.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What went wrong?',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
