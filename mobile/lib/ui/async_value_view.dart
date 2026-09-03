import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import 'empty_state.dart';

/// Renders an [AsyncValue]: spinner while loading, a friendly error with a
/// Retry button on failure, otherwise [data].
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;
  final WidgetBuilder? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () =>
          loading?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (err, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: err is ApiException ? err.message : 'Please try again.',
        action: onRetry == null
            ? null
            : FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
      ),
    );
  }
}

extension PullToRefresh on WidgetRef {
  /// A [RefreshIndicator.onRefresh] handler that keeps the spinner up until the
  /// provider has actually re-fetched. A failure is swallowed here because the
  /// rebuilt [AsyncValueView] surfaces it as an inline error + Retry.
  Future<void> pullToRefresh(Refreshable<Future<Object?>> provider) =>
      pullToRefreshAll([provider]);

  /// [pullToRefresh] for a screen backed by more than one provider — the spinner
  /// stays up until every one has re-fetched.
  Future<void> pullToRefreshAll(
    List<Refreshable<Future<Object?>>> providers,
  ) async {
    final done = [for (final p in providers) refresh(p)];
    try {
      await Future.wait(done);
    } catch (_) {
      /* surfaced by AsyncValueView */
    }
  }
}
