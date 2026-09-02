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
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Something went wrong',
        message: err is ApiException ? err.message : 'Please try again.',
        action: onRetry == null
            ? null
            : FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}
