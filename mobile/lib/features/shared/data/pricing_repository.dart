import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../domain/pricing_preview.dart';

class PricingRepository {
  PricingRepository(this._api);
  final ApiClient _api;

  Future<PricingPreview> preview(String itemPrice) async {
    final data = await _api.get('/api/pricing/preview', query: {'item_price': itemPrice});
    return PricingPreview.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final pricingRepositoryProvider = Provider<PricingRepository>(
  (ref) => PricingRepository(ref.watch(apiClientProvider)),
);

final pricingPreviewProvider = FutureProvider.family<PricingPreview, String>(
  (ref, itemPrice) => ref.watch(pricingRepositoryProvider).preview(itemPrice),
);
