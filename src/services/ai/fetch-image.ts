/** Image media types Claude accepts. */
export type ImageMedia = 'image/jpeg' | 'image/png' | 'image/webp' | 'image/gif';

/** Fetches an image URL and returns it base64-encoded, ready for a vision request. */
export async function fetchImage(url: string): Promise<{ data: string; mediaType: ImageMedia }> {
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`Could not fetch image (${res.status})`);
  }
  const header = (res.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  const mediaType: ImageMedia =
    header === 'image/png' || header === 'image/webp' || header === 'image/gif'
      ? header
      : 'image/jpeg';
  const buf = Buffer.from(await res.arrayBuffer());
  return { data: buf.toString('base64'), mediaType };
}
