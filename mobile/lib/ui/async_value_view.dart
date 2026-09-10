import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_exception.dart';
import '../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () =>
          loading?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (err, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.errorGenericTitle,
        message: err is ApiException ? err.message : l10n.errorPleaseTryAgain,
        action: onRetry == null
            ? null
            : FilledButton.tonal(
                onPressed: onRetry,
                child: Text(l10n.actionRetry),
              ),
      ),
    );
  }
}

/// Combines 4 [AsyncValue]s into one — loading while any is still loading,
/// the first error hit if any failed, otherwise all 4 values together as a
/// record. Lets a screen backed by several providers (e.g. My Orders, which
/// merges wants + orders + negotiations + an id map) go through
/// [AsyncValueView] like every single-provider screen does, instead of
/// hand-rolling its own loading/error branches.
AsyncValue<(A, B, C, D)> combine4<A, B, C, D>(
  AsyncValue<A> a,
  AsyncValue<B> b,
  AsyncValue<C> c,
  AsyncValue<D> d,
) {
  for (final v in [a, b, c, d]) {
    if (v is AsyncError) return AsyncError(v.error, v.stackTrace);
  }
  final av = a.valueOrNull;
  final bv = b.valueOrNull;
  final cv = c.valueOrNull;
  final dv = d.valueOrNull;
  if (av == null || bv == null || cv == null || dv == null) {
    return const AsyncLoading();
  }
  return AsyncData((av, bv, cv, dv));
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
