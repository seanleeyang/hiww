import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/countries.dart';
import '../../../ui/async_value_view.dart';
import '../../../ui/hero_image.dart';
import '../../../ui/marketplace_bits.dart';
import '../../../ui/responsive_body.dart';
import '../../../ui/soft_card.dart';
import '../../../ui/stock_images.dart';
import '../../auth/application/auth_controller.dart';
import '../../shared/presentation/reviews_preview.dart';
import '../../wants/presentation/post_want_sheet.dart';
import '../data/trips_repository.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tripDetailProvider(tripId));
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip')),
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
                    fallbackAsset: stockForCountry(trip.arrivalCountry),
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
                            '${trip.maxWeightKg.toStringAsFixed(trip.maxWeightKg % 1 == 0 ? 0 : 1)} kg spare · up to ${trip.maxItems} items',
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
                      onPressed: () => showPostWantSheet(
                        context,
                        sourceCountry: trip.arrivalCountry,
                        sourceCity: trip.arrivalCity,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Request from this trip'),
                    ),
                  if (isMine)
                    Text(
                      'This is your trip. Shoppers can request items along this route.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
