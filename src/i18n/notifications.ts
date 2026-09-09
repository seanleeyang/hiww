import type { SupportedLocale } from '@/i18n/locale';
import type { NotificationType } from '@/services/notify';

type Params = Record<string, string | number | boolean>;

/** "The traveler"/"The shopper" — inline role labels used inside several bodies. */
function roleLabel(locale: SupportedLocale, role: string): string {
  const traveler = locale === 'th' ? 'นักเดินทาง' : 'The traveler';
  const shopper = locale === 'th' ? 'ผู้ซื้อ' : 'The shopper';
  return role === 'traveler' ? traveler : shopper;
}

function disputeStatusLabel(locale: SupportedLocale, status: string | number | boolean): string {
  if (locale !== 'th') return String(status);
  return status === 'resolved' ? 'ได้รับการแก้ไขแล้ว' : status === 'closed' ? 'ปิดเรื่องแล้ว' : String(status);
}

type Rendered = { subject: string; body: string };
type Template = (locale: SupportedLocale, p: Params) => Rendered;

/** One entry per distinct notification wording. Keyed by `type`, or
 * `type:variant` when the same event has different text for each recipient —
 * `variant` travels in `params._variant` (see `recordNotification`). */
const TEMPLATES: Record<string, Template> = {
  'offer_received:from_traveler': (l, p) =>
    l === 'th'
      ? {
          subject: 'มีข้อเสนอใหม่สำหรับรายการต้องการของคุณ',
          body: `นักเดินทางเสนอที่จะนำ "${p.item}" มาให้ในราคา ${p.price} รับ ต่อรอง หรือปฏิเสธภายใน ${p.hours} ชม.`,
        }
      : {
          subject: 'New offer on your want',
          body: `A traveler offered to bring "${p.item}" for ${p.price}. Accept, counter, or decline within ${p.hours}h.`,
        },
  'offer_received:from_shopper': (l, p) =>
    l === 'th'
      ? {
          subject: 'มีคนขอสินค้าจากทริปของคุณ',
          body: `ผู้ซื้อต้องการ "${p.item}" จากทริปของคุณในราคา ${p.price} รับ ต่อรอง หรือปฏิเสธภายใน ${p.hours} ชม.`,
        }
      : {
          subject: 'Someone requested an item from your trip',
          body: `A shopper wants "${p.item}" from your trip for ${p.price}. Accept, counter, or decline within ${p.hours}h.`,
        },
  'offer_accepted:by_shopper': (l, p) =>
    l === 'th'
      ? {
          subject: 'ข้อเสนอของคุณได้รับการยอมรับแล้ว',
          body: `ผู้ซื้อรับข้อเสนอของคุณสำหรับ "${p.item}" แล้ว ต่อไปพวกเขาจะชำระเงิน — คุณจะได้รับแจ้งเมื่อยืนยันแล้ว`,
        }
      : {
          subject: 'Your offer was accepted',
          body: `The shopper accepted your offer on "${p.item}". They'll pay next — you'll get a heads-up when it's confirmed.`,
        },
  'offer_accepted:by_traveler': (l, p) =>
    l === 'th'
      ? {
          subject: 'ข้อเสนอต่อรองของคุณได้รับการยอมรับแล้ว',
          body: `นักเดินทางรับราคาของคุณสำหรับ "${p.item}" แล้ว ชำระเงินภายใน ${p.minutes} นาที ไม่เช่นนั้นคำสั่งซื้อจะถูกยกเลิก`,
        }
      : {
          subject: 'Your counter-offer was accepted',
          body: `The traveler accepted your price on "${p.item}". Pay within ${p.minutes} minutes or the order is cancelled.`,
        },
  'offer_accepted:shopper_self': (l, p) =>
    l === 'th'
      ? {
          subject: 'คุณยอมรับข้อเสนอแล้ว',
          body: `คุณยอมรับข้อเสนอสำหรับ "${p.item}" แล้ว ชำระเงินภายใน ${p.minutes} นาที ไม่เช่นนั้นคำสั่งซื้อจะถูกยกเลิก`,
        }
      : {
          subject: 'You accepted the offer',
          body: `You accepted the offer on "${p.item}". Pay within ${p.minutes} minutes or the order is cancelled.`,
        },
  'offer_accepted:traveler_self': (l, p) =>
    l === 'th'
      ? {
          subject: 'คุณยอมรับราคาแล้ว',
          body: `คุณยอมรับราคาของผู้ซื้อสำหรับ "${p.item}" แล้ว ต่อไปพวกเขาจะชำระเงิน — คุณจะได้รับแจ้งเมื่อยืนยันแล้ว`,
        }
      : {
          subject: 'You accepted the price',
          body: `You accepted the shopper's price on "${p.item}". They'll pay next — you'll get a heads-up when it's confirmed.`,
        },
  offer_countered: (l, p) => {
    const who = roleLabel(l, String(p.role));
    const canStillCounter = Boolean(p.canStillCounter);
    if (l === 'th') {
      return {
        subject: 'มีการต่อรองราคาใหม่',
        body: `${who}ต่อราคาที่ ${p.price} สำหรับ "${p.item}" ${
          canStillCounter ? 'รับ ต่อรอง หรือปฏิเสธ' : 'รับหรือปฏิเสธ'
        }ภายใน ${p.hours} ชม.`,
      };
    }
    return {
      subject: 'New counter-offer',
      body: `${who} countered at ${p.price} on "${p.item}". ${
        canStillCounter ? 'Accept, counter, or decline' : 'Accept or decline'
      } within ${p.hours}h.`,
    };
  },
  offer_declined: (l, p) => {
    const who = roleLabel(l, String(p.role));
    return l === 'th'
      ? { subject: 'ข้อเสนอถูกปฏิเสธ', body: `${who}ปฏิเสธข้อเสนอสำหรับ "${p.item}"` }
      : { subject: 'Offer declined', body: `${who} declined on "${p.item}".` };
  },
  'offer_expired:traveler': (l, p) =>
    l === 'th'
      ? {
          subject: 'การเจรจาหมดเวลา',
          body: `ไม่มีใครตอบกลับทันเวลาสำหรับ "${p.item}" ข้อเสนอจึงหมดอายุ คุณสามารถเสนอราคาใหม่ได้หากยังสนใจอยู่`,
        }
      : {
          subject: 'Negotiation timed out',
          body: `Nobody responded in time on "${p.item}", so the offer expired. You can make a fresh offer if you're still interested.`,
        },
  'offer_expired:shopper': (l, p) =>
    l === 'th'
      ? { subject: 'การเจรจาหมดเวลา', body: `ข้อเสนอสำหรับ "${p.item}" หมดอายุเนื่องจากไม่มีการตอบกลับทันเวลา` }
      : { subject: 'Negotiation timed out', body: `An offer on "${p.item}" expired with no response in time.` },
  payment_claimed: (l, p) =>
    l === 'th'
      ? {
          subject: 'ผู้ซื้อแจ้งว่าชำระเงินแล้ว',
          body: `ผู้ซื้อทำเครื่องหมายว่าชำระเงินแล้วสำหรับ "${p.item}" กรุณารอ Hiww ยืนยันก่อนซื้อสินค้า`,
        }
      : {
          subject: 'Shopper says the payment is sent',
          body: `The shopper marked payment as sent for "${p.item}". Wait for Hiww to confirm it before you buy anything.`,
        },
  'payment_confirmed:shopper': (l, p) =>
    l === 'th'
      ? { subject: 'ยืนยันการชำระเงินแล้ว', body: `ยืนยันการชำระเงินสำหรับ "${p.item}" แล้ว นักเดินทางสามารถซื้อและจัดส่งได้เลย` }
      : {
          subject: 'Payment confirmed',
          body: `Your payment for "${p.item}" is confirmed. The traveler can buy and ship it now.`,
        },
  'payment_confirmed:traveler': (l, p) =>
    l === 'th'
      ? {
          subject: 'ได้รับการชำระเงินแล้ว — จัดส่งได้เลย',
          body: `Hiww ยืนยันการชำระเงินของผู้ซื้อสำหรับ "${p.item}" แล้ว ไปซื้อสินค้าแล้วทำเครื่องหมายว่าจัดส่งแล้วได้เลย`,
        }
      : {
          subject: 'Payment received — you can ship',
          body: `Hiww confirmed the shopper's payment for "${p.item}". Go ahead and buy the item, then mark it shipped.`,
        },
  'payment_timeout:shopper': (l, p) =>
    l === 'th'
      ? {
          subject: 'คำสั่งซื้อของคุณถูกยกเลิก',
          body: `คุณไม่ได้ชำระเงินทันเวลาสำหรับ "${p.item}" คำสั่งซื้อจึงถูกยกเลิก รายการต้องการของคุณเปิดอีกครั้งแล้วหากยังต้องการอยู่`,
        }
      : {
          subject: 'Your order was cancelled',
          body: `You didn't pay in time for "${p.item}", so the order was cancelled. Your want is open again if you'd still like it.`,
        },
  'payment_timeout:traveler': (l, p) =>
    l === 'th'
      ? { subject: 'คำสั่งซื้อถูกยกเลิก — ไม่ได้ชำระเงินทันเวลา', body: `ผู้ซื้อไม่ได้ชำระเงินทันเวลาสำหรับ "${p.item}" คำสั่งซื้อจึงถูกยกเลิก` }
      : {
          subject: "Order cancelled — payment wasn't made in time",
          body: `The shopper didn't pay in time for "${p.item}", so the order was cancelled.`,
        },
  purchase_proof: (l, p) =>
    l === 'th'
      ? {
          subject: 'นักเดินทางซื้อสินค้าของคุณแล้ว',
          body: `นักเดินทางซื้อ "${p.item}" และแนบใบเสร็จร้านค้าแล้ว จะจัดส่งเมื่อกลับถึง`,
        }
      : {
          subject: 'The traveler bought your item',
          body: `The traveler bought "${p.item}" and attached the shop receipt. They'll ship it once they're back.`,
        },
  shipped: (l, p) =>
    l === 'th'
      ? { subject: 'สินค้าของคุณกำลังจัดส่ง', body: `นักเดินทางทำเครื่องหมายว่า "${p.item}" จัดส่งแล้ว ยืนยันการรับสินค้าในแอปเมื่อได้รับ` }
      : {
          subject: 'Your item is on the way',
          body: `The traveler marked "${p.item}" as shipped. Confirm receipt in the app once it arrives.`,
        },
  'delivered:traveler': (l, p) =>
    l === 'th'
      ? { subject: 'คำสั่งซื้อเสร็จสมบูรณ์ — กำลังจ่ายเงิน', body: `ผู้ซื้อยืนยันว่าได้รับ "${p.item}" แล้ว Hiww จะส่งเงินให้คุณในเร็วๆ นี้` }
      : {
          subject: 'Order complete — payout on the way',
          body: `The shopper confirmed they received "${p.item}". Hiww will send your payout shortly.`,
        },
  'delivered:shopper': (l, p) =>
    l === 'th'
      ? { subject: 'คำสั่งซื้อเสร็จสมบูรณ์', body: `คุณยืนยันการรับ "${p.item}" แล้ว แตะเพื่อรีวิวนักเดินทาง` }
      : { subject: 'Order complete', body: `You confirmed receipt of "${p.item}". Tap to leave the traveler a review.` },
  payout_sent: (l, p) =>
    l === 'th'
      ? {
          subject: 'คุณได้รับเงินแล้ว',
          body: `Hiww โอนเงิน ${p.amount} สำหรับ "${p.item}" ผ่าน ${p.method} (อ้างอิง ${p.reference}) ให้คุณแล้ว`,
        }
      : {
          subject: 'You’ve been paid',
          body: `Hiww sent your payout of ${p.amount} for "${p.item}" via ${p.method} (ref ${p.reference}).`,
        },
  dispute_opened: (l, p) =>
    l === 'th'
      ? {
          subject: 'มีการเปิดข้อพิพาทในคำสั่งซื้อของคุณ',
          body: `อีกฝ่ายเปิดข้อพิพาทสำหรับ "${p.item}" Hiww จะตรวจสอบและติดต่อกลับ`,
        }
      : {
          subject: 'A dispute was opened on your order',
          body: `The other party opened a dispute on "${p.item}". Hiww will review it and be in touch.`,
        },
  dispute_resolved: (l, p) => {
    const status = disputeStatusLabel(l, p.status);
    return l === 'th'
      ? { subject: `ข้อพิพาท${status}`, body: `Hiww ${status}ข้อพิพาทสำหรับ "${p.item}": ${p.resolution}` }
      : { subject: `Dispute ${p.status}`, body: `Hiww ${p.status} the dispute on "${p.item}": ${p.resolution}` };
  },
  message_flagged: (l) =>
    l === 'th'
      ? {
          subject: 'ข้อความถูกลบ',
          body: 'ข้อความแชทของคุณข้อความหนึ่งไม่เป็นไปตามแนวทางของ Hiww จึงถูกลบออก กำลังอยู่ระหว่างตรวจสอบ',
        }
      : {
          subject: 'A message was removed',
          body: "One of your chat messages didn't meet Hiww's chat guidelines and was removed. It's under review.",
        },
};

/** Renders a notification's subject/body in `locale`. `type` is the stored
 * `NotificationType`; pass `params._variant` when the event has more than one
 * distinct wording (see `TEMPLATES` keys above) — falls back to the bare
 * `type` when there's only one. */
export function renderNotification(
  locale: SupportedLocale,
  type: NotificationType,
  params: Params = {}
): Rendered {
  const variant = params._variant;
  const key = variant ? `${type}:${variant}` : type;
  const template = TEMPLATES[key] ?? TEMPLATES[type];
  if (!template) return { subject: type, body: '' };
  return template(locale, params);
}
