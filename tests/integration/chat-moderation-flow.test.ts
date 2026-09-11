import { makeTestApp, closeTestApp, createUser, authHeader, type TestContext } from '../helpers/test-app';
import { createAcceptedOrder } from '../helpers/flows';
import { __setQrDetector } from '@/services/qr-check';
import { __setChatModerationAnalyzer } from '@/services/ai';

/**
 * The test run uses the mock chat moderation analyzer (AI_CHAT_MODERATION
 * defaults to `mock`), which keys risk off the message body: `suspicious` →
 * high, `flagme` → medium, anything else → low. The instant regex pass runs
 * regardless of the mock/real split — a phone number or email always trips it.
 */
describe('AI chat moderation', () => {
  let ctx: TestContext;

  beforeEach(async () => {
    ctx = await makeTestApp();
  });

  afterEach(async () => {
    await closeTestApp(ctx);
    __setQrDetector(undefined);
    __setChatModerationAnalyzer(undefined);
  });

  const send = (
    order: Awaited<ReturnType<typeof createAcceptedOrder>>,
    body?: string,
    imageUrl?: string
  ) =>
    ctx.app.inject({
      method: 'POST',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
      payload: { body, image_url: imageUrl },
    });

  const reviewQueue = async (admin: Awaited<ReturnType<typeof createUser>>) => {
    const res = await ctx.app.inject({ method: 'GET', url: '/api/admin/reviews', headers: authHeader(admin) });
    expect(res.statusCode).toBe(200);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return res.json().data.queue as any[];
  };

  it('an ordinary message sends cleanly with no warning and never hits the queue', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'Hi! Any update on the purchase?');
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeNull();

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message')).toBe(false);
  });

  it('a LINE mention and an @handle are both redacted', async () => {
    const order = await createAcceptedOrder(ctx);

    const lineRes = await send(order, "add me on Line, it's faster");
    expect(lineRes.json().data.warning).toBeTruthy();

    const igRes = await send(order, 'find me @john.doe123 on instagram');
    expect(igRes.json().data.warning).toBeTruthy();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const bodies = list.json().data.items.map((m: { body: string }) => m.body);
    expect(bodies[0]).not.toMatch(/line/i);
    expect(bodies[0]).toContain('[hidden]');
    expect(bodies[1]).not.toContain('@john.doe123');
    expect(bodies[1]).toContain('[hidden]');
  });

  it('Thai-script leakage attempts are redacted too, embedded in running text with no spaces', async () => {
    const order = await createAcceptedOrder(ctx);

    // "add me on Line, easier" — no spaces around the keyword, the normal
    // way Thai is actually typed. \b-based patterns would miss this.
    const lineRes = await send(order, 'แอดไลน์หน่อยครับสะดวกกว่า');
    expect(lineRes.json().data.warning).toBeTruthy();

    // "my promptpay is 98268203" in Thai — keyword + a number under the
    // general 9-digit threshold, same contextual-sweep behaviour as English.
    const payRes = await send(order, 'พร้อมเพย์ของฉันคือ98268203');
    expect(payRes.json().data.warning).toBeTruthy();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const bodies = list.json().data.items.map((m: { body: string }) => m.body);
    expect(bodies[0]).not.toContain('ไลน์');
    expect(bodies[0]).toContain('[hidden]');
    expect(bodies[1]).not.toContain('98268203');
    expect(bodies[1]).toContain('[hidden]');
  });

  it('a phone number is redacted in place, not stripped from the whole message', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, "Call me at 081-234-5678, it's easier");
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeTruthy();

    // The raw number is never stored — redacted before the insert — but the
    // rest of the sentence still comes through, to both participants.
    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items).toHaveLength(1);
    const body = list.json().data.items[0].body as string;
    expect(body).not.toContain('081-234-5678');
    expect(body).toContain('[number hidden]');
    expect(body).toContain("Call me at");
    expect(body).toContain("it's easier");

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'message' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.risk).toBe('medium');
    expect(entry.flags.length).toBeGreaterThan(0);
    expect(entry.hidden).toBe(false); // redaction, not hiding — medium stays visible
  });

  it('bank account numbers and PromptPay mentions are redacted too', async () => {
    const order = await createAcceptedOrder(ctx);

    // An unevenly-grouped bank account number (not the 3-3-4 phone shape).
    const bankRes = await send(order, 'transfer to my bank account 123-4-56789-0 instead');
    expect(bankRes.json().data.warning).toBeTruthy();

    // PromptPay mentioned by name, with no digits in the same message.
    const promptPayRes = await send(order, "I'll send you my PromptPay details separately");
    expect(promptPayRes.json().data.warning).toBeTruthy();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const bodies = list.json().data.items.map((m: { body: string }) => m.body);
    expect(bodies[0]).not.toContain('123-4-56789-0');
    expect(bodies[0]).toContain('[number hidden]');
    expect(bodies[1]).toContain('[hidden]');
  });

  it('a short number next to a payment keyword is redacted even under the general digit threshold', async () => {
    const order = await createAcceptedOrder(ctx);

    // 8 digits — below the general 9-digit phone/account threshold on its
    // own, but "promptpay" right next to it makes the number unambiguous.
    const res = await send(order, 'my promptpay is 98268203');
    expect(res.json().data.warning).toBeTruthy();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const body = list.json().data.items[0].body as string;
    expect(body).not.toContain('98268203');
    expect(body).toContain('[number hidden]');
  });

  it('a bare "ID: ______" handle is redacted even without naming an app', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'ID: xyz123, add me there');
    expect(res.json().data.warning).toBeTruthy();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const body = list.json().data.items[0].body as string;
    expect(body).not.toContain('xyz123');
    expect(body).toContain('[hidden]');
  });

  it('a bare "ID johndoe123" with no colon is redacted too', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'ID johndoe123 add me there');
    expect(res.json().data.warning).toBeTruthy();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const body = list.json().data.items[0].body as string;
    expect(body).not.toContain('johndoe123');
    expect(body).toContain('[hidden]');
  });

  it('"id like"/"id love" (the no-apostrophe "I\'d") is left alone, not redacted', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, "id like to know when it ships, id love an update");
    expect(res.json().data.warning).toBeNull();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items[0].body).toBe(
      "id like to know when it ships, id love an update"
    );
  });

  it('social brand names, short forms, and spelled-out letters are all redacted', async () => {
    const order = await createAcceptedOrder(ctx);

    const cases = [
      'find me on Facebook',
      'just fb me',
      "here's my IG",
      "here's my instagram",
      'add me on WA',
      'f a c e b o o k dot com slash me',
      'L I N E id is xyz',
    ];

    for (const body of cases) {
      const res = await send(order, body);
      expect(res.json().data.warning).toBeTruthy();
    }

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const bodies = list.json().data.items.map((m: { body: string }) => m.body as string);
    for (const body of bodies) {
      expect(body.toLowerCase()).not.toMatch(/facebook|instagram|whatsapp/);
    }
  });

  it('Thai social brand names and their short forms are redacted too', async () => {
    const order = await createAcceptedOrder(ctx);

    const cases = ['แอดติ๊กต๊อกหน่อย', 'มีเฟสบุคไหม', 'ขอเฟสหน่อย', 'ขอฟบหน่อยครับ', 'ขออจหน่อยครับ'];

    for (const body of cases) {
      const res = await send(order, body);
      expect(res.json().data.warning).toBeTruthy();
    }
  });

  it('profanity in English is redacted with its own distinct warning', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, "what the fuck is taking so long, you asshole");
    expect(res.json().data.warning).toBeTruthy();
    expect(res.json().data.warning).toContain('offensive language');
    expect(res.json().data.warning).not.toContain('contact details');

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const body = list.json().data.items[0].body as string;
    expect(body).not.toMatch(/fuck|asshole/i);
    expect(body).toContain('[language warning]');
    expect(body).toContain('what the');
  });

  it('profanity in Thai is redacted the same way', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'ไอเหี้ยส่งของช้ามาก');
    expect(res.json().data.warning).toBeTruthy();
    expect(res.json().data.warning).toContain('offensive language');

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    const body = list.json().data.items[0].body as string;
    expect(body).not.toContain('เหี้ย');
    expect(body).toContain('[language warning]');
  });

  it('a message with both profanity and a leaked contact gets both warnings', async () => {
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, "fuck this, just add me on line xyz123");
    const warning = res.json().data.warning as string;
    expect(warning).toContain('offensive language');
    expect(warning).toContain('contact details');
  });

  it('everyday words that happen to contain a profanity substring are left alone', async () => {
    const order = await createAcceptedOrder(ctx);

    // "assassin", "class", "grass" etc. must not trip the "ass" entry.
    const res = await send(order, 'this class is full of grass and an assassin figurine');
    expect(res.json().data.warning).toBeNull();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items[0].body).toBe(
      'this class is full of grass and an assassin figurine'
    );
  });

  it('a message the AI check calls high-risk is hidden from both participants', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'this is a suspicious message with no contact info');
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeNull(); // regex pass found nothing — this is the AI layer

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'message' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.risk).toBe('high');
    expect(entry.hidden).toBe(true);
    expect(entry.body).toContain('suspicious'); // operator still sees the real text

    const asSender = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(asSender.json().data.items[0].body).toMatch(/your message was removed/i);

    const asCounterparty = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.traveler),
    });
    expect(asCounterparty.json().data.items[0].body).toMatch(/a message was removed/i);
    expect(asCounterparty.json().data.items[0].body).not.toContain('suspicious');

    // The instant regex/QR checks return a `warning` in the send response
    // itself, but this is the async AI check — it runs after that response
    // already went out, so the sender needs an explicit notification.
    const notifications = await ctx.app.inject({
      method: 'GET',
      url: '/api/notifications',
      headers: authHeader(order.shopper),
    });
    const items = notifications.json().data.items as Array<{ type: string; order_id: string }>;
    expect(items.some((n) => n.type === 'message_flagged' && n.order_id === order.orderId)).toBe(
      true
    );
  });

  it('clearing a hidden message restores it to the conversation', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const sendRes = await send(order, 'this is a suspicious message with no contact info');
    const messageId = sendRes.json().data.id;

    await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/messages/${messageId}/clear-flag`,
      headers: authHeader(admin),
    });

    const asCounterparty = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.traveler),
    });
    expect(asCounterparty.json().data.items[0].body).toContain('suspicious');
    expect(asCounterparty.json().data.items[0].body).not.toMatch(/message was removed/i);
  });

  it('the operator can clear a flag out of the queue', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const sendRes = await send(order, 'flagme please, testing the review queue');
    const messageId = sendRes.json().data.id;

    let queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.id === messageId)).toBe(true);

    const clear = await ctx.app.inject({
      method: 'POST',
      url: `/api/admin/messages/${messageId}/clear-flag`,
      headers: authHeader(admin),
    });
    expect(clear.statusCode).toBe(200);

    queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.id === messageId)).toBe(false);
  });

  it('participants never see the flag; the admin does', async () => {
    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);
    await send(order, 'my email is shady@example.com');

    const asShopper = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(asShopper.json().data.items[0].flag_risk).toBeUndefined();

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.order_id === order.orderId)).toBe(true);
  });

  it('a photo with a QR code is rejected outright, not just flagged', async () => {
    __setQrDetector(async () => ({
      found: true,
      payload: 'https://wa.me/1234567890',
      reason: 'a WhatsApp QR code',
    }));

    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, "here's a pic", 'https://example.com/uploads/qr-photo.jpg');
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeTruthy();

    // The photo never gets stored — the caption text does.
    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items[0].image_url).toBeNull();
    expect(list.json().data.items[0].body).toBe("here's a pic");

    const queue = await reviewQueue(admin);
    const entry = queue.find((q) => q.type === 'message' && q.order_id === order.orderId);
    expect(entry).toBeDefined();
    expect(entry.flags).toContain('a WhatsApp QR code');
  });

  it('a plain photo with no QR code sends normally', async () => {
    __setQrDetector(async () => ({ found: false }));

    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, undefined, 'https://example.com/uploads/item-photo.jpg');
    expect(res.statusCode).toBe(201);
    expect(res.json().data.warning).toBeNull();

    const list = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(list.json().data.items[0].image_url).toBe('https://example.com/uploads/item-photo.jpg');

    const queue = await reviewQueue(admin);
    expect(queue.some((q) => q.type === 'message' && q.order_id === order.orderId)).toBe(false);
  });

  it('a non-QR photo the AI vision check calls high-risk is hidden, same as flagged text', async () => {
    // e.g. a phone number written on paper and photographed — not a QR code,
    // so the deterministic decoder can't catch it; only the vision pass can.
    __setQrDetector(async () => ({ found: false }));

    const order = await createAcceptedOrder(ctx);

    const res = await send(order, undefined, 'https://example.com/uploads/suspicious-note.jpg');
    expect(res.statusCode).toBe(201);

    const asSender = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.shopper),
    });
    expect(asSender.json().data.items[0].body).toMatch(/your message was removed/i);
    expect(asSender.json().data.items[0].image_url).toBeNull();

    const asCounterparty = await ctx.app.inject({
      method: 'GET',
      url: `/api/orders/${order.orderId}/messages`,
      headers: authHeader(order.traveler),
    });
    expect(asCounterparty.json().data.items[0].image_url).toBeNull();
  });

  it('a persistently failing AI check is logged to the audit trail, not just silently swallowed', async () => {
    __setChatModerationAnalyzer({
      analyze: async () => {
        throw new Error('authentication_error: invalid x-api-key');
      },
    });

    const admin = await createUser(ctx, { admin: true });
    const order = await createAcceptedOrder(ctx);

    const res = await send(order, 'an ordinary message');
    expect(res.statusCode).toBe(201); // the send itself never fails over this

    const audit = await ctx.app.inject({
      method: 'GET',
      url: '/api/admin/audit?action=message.check_failed',
      headers: authHeader(admin),
    });
    const items = audit.json().data.items as Array<{ summary: string }>;
    expect(items.length).toBeGreaterThan(0);
    expect(items[0].summary).toContain('invalid x-api-key');
  });
});
