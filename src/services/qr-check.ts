import { Jimp } from 'jimp';
import jsQR from 'jsqr';

export interface QrCheckResult {
  found: boolean;
  /** The decoded QR payload, for the audit log only — never shown to users. */
  payload?: string;
  /** Human-readable classification of what kind of QR it looks like. */
  reason?: string;
}

type Detector = (imageUrl: string) => Promise<QrCheckResult>;
let override: Detector | undefined;

/** Test seam — avoids a real network fetch + image decode in tests. */
export function __setQrDetector(detector: Detector | undefined): void {
  override = detector;
}

// A small, highly-compressible file (well under the 5MB upload cap) can still
// declare enormous pixel dimensions — decoding it would allocate a bitmap
// many times larger than the file itself ("decompression bomb"), blocking
// the event loop and risking an OOM crash of the whole (single-process)
// server. 20MP is generous for a phone photo and far below that territory.
const MAX_PIXELS = 20_000_000;

/**
 * Read width/height straight from a PNG/JPEG header, without decoding any
 * pixel data — lets `detectQrCode` reject an oversized image before the
 * expensive (and memory-hungry) full decode below. Returns null for any
 * other/unrecognized format, in which case the caller falls back to
 * decoding it directly (Jimp itself still rejects genuinely unsupported
 * formats — this probe only exists to short-circuit the common bomb case).
 */
function probeImageDimensions(buffer: Buffer): { width: number; height: number } | null {
  // PNG: 8-byte signature, then the IHDR chunk's width/height as big-endian
  // uint32 at fixed offsets.
  if (buffer.length >= 24 && buffer.readUInt32BE(0) === 0x89504e47 && buffer.readUInt32BE(4) === 0x0d0a1a0a) {
    return { width: buffer.readUInt32BE(16), height: buffer.readUInt32BE(20) };
  }

  // JPEG: walk marker segments until a start-of-frame marker, which holds
  // height/width right after the segment length.
  if (buffer.length >= 4 && buffer.readUInt16BE(0) === 0xffd8) {
    let offset = 2;
    while (offset + 9 < buffer.length && buffer[offset] === 0xff) {
      const marker = buffer[offset + 1];
      const isSof = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
      if (isSof) {
        return { height: buffer.readUInt16BE(offset + 5), width: buffer.readUInt16BE(offset + 7) };
      }
      offset += 2 + buffer.readUInt16BE(offset + 2);
    }
  }

  return null;
}

/**
 * Deterministic QR-code detection for a chat photo. There's rarely a
 * legitimate reason to send a QR code in order chat — it's how people share
 * payment details (PromptPay, a bank app's pay-by-QR) or a contact add-me
 * code — so any QR found here is treated as a leakage attempt, no AI
 * judgment call needed, the same way the text regex layer doesn't need one.
 */
export async function detectQrCode(imageUrl: string): Promise<QrCheckResult> {
  if (override) return override(imageUrl);

  try {
    // Without a bound, a stalled origin would hang this fetch (and the
    // message-send request awaiting it) for however long Node's default
    // socket timeout is.
    const res = await fetch(imageUrl, { signal: AbortSignal.timeout(10_000) });
    if (!res.ok) return { found: false };
    const buffer = Buffer.from(await res.arrayBuffer());

    const dimensions = probeImageDimensions(buffer);
    if (dimensions && dimensions.width * dimensions.height > MAX_PIXELS) {
      return { found: false };
    }

    const image = await Jimp.read(buffer);
    const { data, width, height } = image.bitmap;
    const code = jsQR(new Uint8ClampedArray(data), width, height);
    if (!code) return { found: false };

    return { found: true, payload: code.data, reason: classifyPayload(code.data) };
  } catch {
    // Not a decodable image, network hiccup, etc. — never block sending a
    // photo over this; worst case a QR slips through undetected.
    return { found: false };
  }
}

function classifyPayload(payload: string): string {
  if (/^000201/.test(payload)) return 'a PromptPay/EMVCo payment QR code';
  if (/^tel:/i.test(payload)) return 'a phone number QR code';
  if (/wa\.me|whatsapp/i.test(payload)) return 'a WhatsApp QR code';
  if (/line\.me|^line:\/\//i.test(payload)) return 'a LINE QR code';
  if (/^begin:vcard/i.test(payload)) return 'a contact card QR code';
  if (/^https?:\/\//i.test(payload)) return 'a QR code linking off-platform';
  return 'a QR code';
}
