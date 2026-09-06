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
    const res = await fetch(imageUrl);
    if (!res.ok) return { found: false };
    const buffer = Buffer.from(await res.arrayBuffer());

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
