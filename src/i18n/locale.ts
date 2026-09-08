export type SupportedLocale = 'en' | 'th';

/**
 * Only two locales exist, so a substring check on the raw `Accept-Language`
 * header is enough — no need for full RFC 4647 q-value parsing.
 */
export function resolveLocale(header?: string): SupportedLocale {
  return typeof header === 'string' && header.toLowerCase().includes('th') ? 'th' : 'en';
}
