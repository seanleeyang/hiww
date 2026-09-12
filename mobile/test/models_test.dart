import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/features/discovery/domain/feed_item.dart';
import 'package:hiww_mobile/features/discovery/domain/route_match.dart';
import 'package:hiww_mobile/features/orders/domain/order.dart';
import 'package:hiww_mobile/features/shared/domain/pricing_preview.dart';
import 'package:hiww_mobile/features/wants/domain/offer.dart';
import 'package:hiww_mobile/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  test('FeedItem parses a trip card', () {
    final item = FeedItem.fromJson({
      'kind': 'trip',
      'id': 't1',
      'trip': {
        'id': 't1',
        'traveler_id': 'u1',
        'departure_country': 'TH',
        'arrival_country': 'JP',
        'arrival_city': 'Tokyo',
        'departure_date': '2026-11-12T08:00:00.000Z',
        'return_date': '2026-11-19T08:00:00.000Z',
        'max_weight_kg': '8',
        'max_items': 5,
        'status': 'published',
      },
      'traveler': {'id': 'u1', 'full_name': 'Nuch S', 'rating_avg': 4.9, 'delivered_count': 147},
      'match_count': 3,
      'earn_min': '520',
      'earn_max': '1200',
    });

    expect(item.isTrip, true);
    expect(item.trip!.toLabel(), 'Tokyo');
    expect(item.trip!.route(), 'Bangkok → Tokyo');
    expect(item.owner!.fullName, 'Nuch S');
    expect(item.owner!.deliveredCount, 147);
    expect(item.matchCount, 3);
    expect(item.earnMin, '520');
    expect(item.earnMax, '1200');
  });

  test('FeedItem parses a want card', () {
    final item = FeedItem.fromJson({
      'kind': 'want',
      'id': 'w1',
      'request': {
        'id': 'w1',
        'shopper_id': 'u2',
        'item_description': 'Nike Dunk Low Panda',
        'source_country': 'JP',
        'source_city': 'Tokyo',
        'category': 'sneakers',
        'budget': '6500.00',
        'quantity': 3,
        'title': 'Nike Dunk Panda',
        'need_by': '2026-12-01T00:00:00.000Z',
        'status': 'open',
      },
      'shopper': {'id': 'u2', 'full_name': 'Mika K'},
      'match_count': 2,
    });

    expect(item.isTrip, false);
    expect(item.want!.displayTitle, 'Nike Dunk Panda');
    expect(item.want!.budgetLabel, '฿6,500');
    expect(item.want!.quantity, 3);
    expect(item.want!.needByLabel(l10n), 'Need by Dec 1');
    expect(item.want!.sourceLabel, 'Tokyo');
  });

  test('Offer parses both shapes', () {
    final onRequest = Offer.fromJson({
      'id': 'o1',
      'quoted_price': '1500.00',
      'delivery_date': '2026-11-18T10:00:00.000Z',
      'status': 'pending',
      'traveler_name': 'Nuch S',
    });
    expect(onRequest.priceLabel, '฿1,500');
    expect(onRequest.deliveryLabel(l10n), 'Deliver by Nov 18');

    final mine = Offer.fromJson({
      'id': 'o2',
      'quoted_price': '999.00',
      'status': 'accepted',
      'request_id': 'w1',
      'request_item': 'Nike Dunk Panda',
    });
    expect(mine.requestItem, 'Nike Dunk Panda');
  });

  test('Offer parses negotiation state (round, turn, price history)', () {
    final offer = Offer.fromJson({
      'id': 'o3',
      'quoted_price': '110.00',
      'status': 'pending',
      'round': 2,
      'last_actor': 'traveler',
      'respond_by': '2026-11-20T00:00:00.000Z',
      'my_turn': true,
      'can_counter': false,
      'price_history': [
        {'by': 'traveler', 'price': '100.00', 'at': '2026-11-18T09:00:00.000Z'},
        {'by': 'shopper', 'price': '120.00', 'at': '2026-11-18T10:00:00.000Z'},
        {'by': 'traveler', 'price': '110.00', 'at': '2026-11-18T11:00:00.000Z'},
      ],
    });

    expect(offer.round, 2);
    expect(offer.lastActor, 'traveler');
    expect(offer.myTurn, true);
    expect(offer.canCounter, false);
    expect(offer.isNegotiating, true);
    expect(offer.priceHistory, hasLength(3));
    expect(offer.priceHistory.last.by, 'traveler');
    expect(offer.priceHistory.last.price, '110.00');

    final fresh = Offer.fromJson({'id': 'o4', 'quoted_price': '50.00', 'status': 'pending'});
    expect(fresh.round, 0);
    expect(fresh.isNegotiating, false);
    expect(fresh.priceHistory, isEmpty);
  });

  test('Order parses stage timestamps and review flags', () {
    final o = Order.fromJson({
      'id': 'ord1',
      'shopper_id': 's',
      'traveler_id': 't',
      'item_description': 'Dyson Airwrap',
      'total_price': '18000',
      'fees': '1200',
      'status': 'in_transit',
      'confirmed_at': '2026-11-14T00:00:00.000Z',
      'purchased_at': '2026-11-15T00:00:00.000Z',
      'purchase_proof_url': 'https://cdn.hiww.test/receipt.jpg',
      'shipped_at': '2026-11-16T00:00:00.000Z',
      'delivered_at': null,
      'can_review': false,
      'counterparty': {'id': 't', 'full_name': 'Nuch S'},
    });
    expect(o.totalLabel, '฿18,000');
    expect(o.feesLabel, '฿1,200');
    expect(o.purchasedAt, isNotNull);
    expect(o.purchaseProofUrl, 'https://cdn.hiww.test/receipt.jpg');
    expect(o.shippedAt, isNotNull);
    expect(o.deliveredAt, isNull);
    expect(o.counterparty!.fullName, 'Nuch S');
    expect(o.hasPricingBreakdown, isFalse); // legacy order, no reward/total split
    expect(o.travellerRewardLabel, isNull);
  });

  test('Order parses the MVP pricing-model breakdown when present', () {
    final o = Order.fromJson({
      'id': 'ord2',
      'shopper_id': 's',
      'traveler_id': 't',
      'item_description': 'Nike Dunk Panda',
      'total_price': '1000',
      'fees': '100',
      'traveller_reward': '100',
      'shopper_total': '1200',
      'traveller_payout': '1100',
      'currency': 'THB',
      'status': 'pending_payment',
    });
    expect(o.hasPricingBreakdown, isTrue);
    expect(o.travellerRewardLabel, '฿100');
    expect(o.shopperTotalLabel, '฿1,200');
    expect(o.travellerPayoutLabel, '฿1,100');
  });

  test('PricingPreview parses the worked ฿1,000 example', () {
    final p = PricingPreview.fromJson({
      'itemPrice': '1000',
      'travellerReward': '100',
      'serviceFee': '100',
      'shopperTotal': '1200',
      'travellerPayout': '1100',
      'platformGrossRevenue': '100',
      'currency': 'THB',
    });
    expect(p.itemPriceLabel, '฿1,000');
    expect(p.travellerRewardLabel, '฿100');
    expect(p.serviceFeeLabel, '฿100');
    expect(p.shopperTotalLabel, '฿1,200');
    expect(p.travellerPayoutLabel, '฿1,100');
  });

  test('RouteMatch parses count + sample', () {
    final m = RouteMatch.fromJson({
      'count': 3,
      'sample': [
        {
          'id': 't1',
          'traveler_name': 'A',
          'departure_country': 'TH',
          'arrival_country': 'JP',
          'arrival_city': 'Tokyo',
        }
      ],
    });
    expect(m.count, 3);
    expect(m.sample.single.route, 'TH → Tokyo');
  });
}
