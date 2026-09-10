import { describe, expect, it } from 'vitest';
import { orderStatusLabel, orderStatusTone, riskLabel, riskTone } from './status';

describe('orderStatusLabel', () => {
  it('maps raw DB statuses to the same friendly labels the mobile app uses', () => {
    expect(orderStatusLabel('pending_payment')).toBe('Awaiting payment');
    expect(orderStatusLabel('confirmed')).toBe('Paid');
    expect(orderStatusLabel('in_transit')).toBe('In transit');
    expect(orderStatusLabel('delivered')).toBe('Delivered');
    expect(orderStatusLabel('cancelled')).toBe('Cancelled');
  });

  it('falls back to the raw string for an unknown status rather than throwing', () => {
    expect(orderStatusLabel('something_new')).toBe('something_new');
  });
});

describe('orderStatusTone', () => {
  it('flags delivered as positive and cancelled as negative', () => {
    expect(orderStatusTone('delivered')).toBe('positive');
    expect(orderStatusTone('cancelled')).toBe('negative');
    expect(orderStatusTone('pending_payment')).toBe('warning');
    expect(orderStatusTone('in_transit')).toBe('neutral');
  });
});

describe('risk helpers', () => {
  it('labels and tones risk levels', () => {
    expect(riskLabel('high')).toBe('High risk');
    expect(riskTone('high')).toBe('negative');
    expect(riskTone('medium')).toBe('warning');
    expect(riskTone('low')).toBe('neutral');
  });
});
