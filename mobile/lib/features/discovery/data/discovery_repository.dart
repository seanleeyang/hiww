import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/feed_item.dart';
import '../domain/route_match.dart';

class DiscoveryRepository {
  DiscoveryRepository(this._api);
  final ApiClient _api;

  Future<List<FeedItem>> feed({
    String type = 'all',
    String? category,
    String? country,
  }) async {
    final query = <String, dynamic>{'type': type};
    if (category != null && category.isNotEmpty) query['category'] = category;
    if (country != null && country.isNotEmpty) query['country'] = country;
    final data = await _api.get('/api/discover/feed', query: query);
    final items = ((data as Map)['items'] as List?) ?? [];
    return items
        .map((e) => FeedItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RouteMatch> routeMatch(
    String sourceCountry, {
    String? sourceCity,
  }) async {
    final query = <String, dynamic>{'source_country': sourceCountry};
    if (sourceCity != null && sourceCity.isNotEmpty)
      query['source_city'] = sourceCity;
    final data = await _api.get('/api/discover/route-match', query: query);
    return RouteMatch.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) => DiscoveryRepository(ref.watch(apiClientProvider)),
);

typedef FeedQuery = ({String type, String? category, String? country});

final feedProvider = FutureProvider.family<List<FeedItem>, FeedQuery>(
  (ref, q) => ref
      .watch(discoveryRepositoryProvider)
      .feed(type: q.type, category: q.category, country: q.country),
);

final routeMatchProvider = FutureProvider.family<RouteMatch, String>(
  (ref, country) => ref.watch(discoveryRepositoryProvider).routeMatch(country),
);
