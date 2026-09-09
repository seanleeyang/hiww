import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/countries.dart';
import '../../../core/guest_guard.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/responsive_body.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/stock_images.dart';
import '../../auth/application/auth_controller.dart';
import '../../shared/presentation/reviews_preview.dart';
import '../../wants/domain/want_draft.dart';
import '../data/trips_repository.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(tripDetailProvider(tripId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripDetailTitle)),
      body: ResponsiveBody(
        child: RefreshIndicator(
          onRefresh: () => ref.pullToRefresh(tripDetailProvider(tripId).future),
          child: AsyncValueView(
            value: detail,
            onRetry: () => ref.invalidate(tripDetailProvider(tripId)),
            data: (d) {
              final trip = d.trip;
              final isMine = me?.id == trip.travelerId;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  HeroImage(
                    url: trip.coverImageUrl,
                    fallbackAsset: stockForTrip(city: trip.arrivalCity, countryCode: trip.arrivalCountry),
                    height: 190,
                    heroTag: 'trip-${trip.id}',
                    enableFullscreen: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trip.title ?? trip.route,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (d.traveler != null)
                    AvatarRating(user: d.traveler!, radius: 22),
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RouteChip(route: trip.route, dates: trip.dates),
                        const SizedBox(height: 12),
                        IconLine(
                          Icons.public,
                          '${countryName(trip.departureCountry)} → ${countryName(trip.arrivalCountry)}',
                        ),
                        if (trip.maxWeightKg > 0) ...[
                          const SizedBox(height: 6),
                          IconLine(
                            Icons.luggage_outlined,
                            l10n.tripSpareCapacity(
                              trip.maxWeightKg.toStringAsFixed(trip.maxWeightKg % 1 == 0 ? 0 : 1),
                              trip.maxItems,
                            ),
                          ),
                        ],
                        if (trip.note != null) ...[
                          const SizedBox(height: 10),
                          Text(trip.note!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ReviewsPreview(userId: trip.travelerId),
                  const SizedBox(height: 8),
                  if (!isMine)
                    FilledButton.icon(
                      onPressed: () {
                        if (!requireSignedIn(context, ref)) return;
                        context.push(
                          '/wants/new',
                          extra: PostWantPrefill(
                            sourceCountry: trip.arrivalCountry,
                            sourceCity: trip.arrivalCity,
                            targetTripId: trip.id,
                            targetTravelerName: d.traveler?.fullName,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(l10n.actionRequestFromThisTrip),
                    ),
                  if (isMine) ...[
                    Text(
                      l10n.tripDetailOwnerNote,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (trip.status == 'published') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.push('/trips/${trip.id}/edit', extra: trip),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.tripEditTitle),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
