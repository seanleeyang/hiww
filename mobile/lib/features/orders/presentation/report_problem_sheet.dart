import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    if (_reason.text.trim().length < 10) {
      setState(() => _error = l10n.errorDescribeProblem);
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
        SnackBar(content: Text(l10n.infoReported)),
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
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.reportProblemTitle,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              l10n.reportProblemSubtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.hintWhatWentWrong,
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
                  : Text(l10n.actionSubmitReport),
            ),
          ],
        ),
      ),
    );
  }
}
