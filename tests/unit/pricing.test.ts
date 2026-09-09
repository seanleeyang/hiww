import { calculatePricing } from '@/services/pricing';

describe('calculatePricing', () => {
  const cases: Array<{
    itemPrice: number;
    travellerReward: string;
    serviceFee: string;
    shopperTotal: string;
    travellerPayout: string;
    platformGrossRevenue: string;
  }> = [
    { itemPrice: 300, travellerReward: '50', serviceFee: '30', shopperTotal: '380', travellerPayout: '350', platformGrossRevenue: '30' },
    { itemPrice: 500, travellerReward: '50', serviceFee: '50', shopperTotal: '600', travellerPayout: '550', platformGrossRevenue: '50' },
    { itemPrice: 1000, travellerReward: '100', serviceFee: '100', shopperTotal: '1200', travellerPayout: '1100', platformGrossRevenue: '100' },
    { itemPrice: 2000, travellerReward: '200', serviceFee: '200', shopperTotal: '2400', travellerPayout: '2200', platformGrossRevenue: '200' },
    { itemPrice: 5000, travellerReward: '500', serviceFee: '500', shopperTotal: '6000', travellerPayout: '5500', platformGrossRevenue: '500' },
    { itemPrice: 10000, travellerReward: '1000', serviceFee: '1000', shopperTotal: '12000', travellerPayout: '11000', platformGrossRevenue: '1000' },
  ];

  for (const c of cases) {
    it(`฿${c.itemPrice} item produces the worked-example breakdown`, () => {
      const result = calculatePricing(c.itemPrice);
      expect(result.travellerReward).toBe(c.travellerReward);
      expect(result.serviceFee).toBe(c.serviceFee);
      expect(result.shopperTotal).toBe(c.shopperTotal);
      expect(result.travellerPayout).toBe(c.travellerPayout);
      expect(result.platformGrossRevenue).toBe(c.platformGrossRevenue);
      expect(result.platformGrossRevenue).toBe(result.serviceFee); // reward is never counted as revenue
      expect(result.currency).toBe('THB');
    });
  }

  it('floors the reward at ฿50 just below the 10% crossover (฿499)', () => {
    const result = calculatePricing(499);
    expect(result.travellerReward).toBe('50'); // 10% of 499 = 49.9, floor wins
    expect(result.serviceFee).toBe('49.9');
  });

  it('switches to the 10% rule just above the crossover (฿501)', () => {
    const result = calculatePricing(501);
    expect(result.travellerReward).toBe('50.1'); // 10% of 501 = 50.1, exceeds the floor
    expect(result.serviceFee).toBe('50.1');
  });

  it('handles a zero item price literally per the formula (reward floors to 50, fee is 0)', () => {
    const result = calculatePricing(0);
    expect(result.travellerReward).toBe('50');
    expect(result.serviceFee).toBe('0');
    expect(result.shopperTotal).toBe('50');
    expect(result.travellerPayout).toBe('50');
  });

  it('rejects a negative item price', () => {
    expect(() => calculatePricing(-100)).toThrow();
  });

  it('handles a decimal item price', () => {
    const result = calculatePricing(333.33);
    expect(result.itemPrice).toBe('333.33');
    expect(result.travellerReward).toBe('50'); // 10% of 333.33 = 33.33, floor wins
    expect(result.serviceFee).toBe('33.33');
  });

  it('rounds to 2 decimal places when 10% doesn\'t divide cleanly', () => {
    const result = calculatePricing(555.55);
    // 10% of 555.55 = 55.555 -> rounds to 55.56 (Decimal.js default ROUND_HALF_UP)
    expect(result.travellerReward).toBe('55.56');
    expect(result.serviceFee).toBe('55.56');
  });

  it('accepts a decimal-string itemPrice, matching how offer.quoted_price is stored', () => {
    const result = calculatePricing('1000.00');
    expect(result.itemPrice).toBe('1000');
    expect(result.travellerReward).toBe('100');
  });
});
