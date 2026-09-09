import '../../../core/format.dart';

/// The same itemized breakdown `src/services/pricing.ts` computes
/// server-side — used to preview a price before an order exists (the actual
/// order is always priced fresh server-side at accept time).
class PricingPreview {
  const PricingPreview({
    required this.itemPrice,
    required this.travellerReward,
    required this.serviceFee,
    required this.shopperTotal,
    required this.travellerPayout,
    required this.platformGrossRevenue,
    required this.currency,
  });

  final String itemPrice;
  final String travellerReward;
  final String serviceFee;
  final String shopperTotal;
  final String travellerPayout;
  final String platformGrossRevenue;
  final String currency;

  String get itemPriceLabel => money(itemPrice);
  String get travellerRewardLabel => money(travellerReward);
  String get serviceFeeLabel => money(serviceFee);
  String get shopperTotalLabel => money(shopperTotal);
  String get travellerPayoutLabel => money(travellerPayout);

  factory PricingPreview.fromJson(Map<String, dynamic> j) => PricingPreview(
        itemPrice: (j['itemPrice'] ?? '0').toString(),
        travellerReward: (j['travellerReward'] ?? '0').toString(),
        serviceFee: (j['serviceFee'] ?? '0').toString(),
        shopperTotal: (j['shopperTotal'] ?? '0').toString(),
        travellerPayout: (j['travellerPayout'] ?? '0').toString(),
        platformGrossRevenue: (j['platformGrossRevenue'] ?? '0').toString(),
        currency: (j['currency'] ?? 'THB').toString(),
      );
}
