// Seed a lively demo dataset for a walk-through of the app.
//
//   npm run db:setup          # fresh database
//   npm run dev               # in another terminal
//   node scripts/seed-demo.mjs
//
// Creates 3 travellers with photo'd trips, 2 shoppers with photo'd wants, and a
// `demo@hiww.test` / `demo1234` account that already has an offer waiting to
// accept. All seeded accounts use the password `demo1234`. Set HIWW_API to point
// at a non-local backend.
const BASE = process.env.HIWW_API || 'http://localhost:3000';

async function api(method, path, { token, body } = {}) {
  const headers = {};
  if (token) headers.authorization = `Bearer ${token}`;
  let payload;
  if (body !== undefined) {
    headers['content-type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const res = await fetch(BASE + path, { method, headers, body: payload });
  const text = await res.text();
  const json = text ? JSON.parse(text) : {};
  if (!res.ok) throw new Error(`${method} ${path} -> ${res.status} ${text}`);
  return json.data ?? json;
}

async function reg(email, name, type) {
  const user = await api('POST', '/api/auth/register', {
    body: { email, full_name: name, user_type: type, phone: '+1 555 0100', password: 'demo1234' },
  });
  // Registration leaves the account unverified (see src/services/otp/); the
  // mock sender echoes the codes back as debug_otp so this script can finish
  // verification without a real inbox/SMS.
  if (user.debug_otp) {
    await api('POST', '/api/auth/verify-otp', {
      token: user.token,
      body: { channel: 'email', code: user.debug_otp.email },
    });
    await api('POST', '/api/auth/verify-otp', {
      token: user.token,
      body: { channel: 'phone', code: user.debug_otp.phone },
    });
  }
  return user;
}

const days = (n) => new Date(Date.now() + n * 864e5).toISOString();

async function uploadStock(token, seed) {
  // Pull a small jpeg from picsum and re-host it through our own upload
  // endpoint so cards have real images.
  const img = await fetch(`https://picsum.photos/seed/${seed}/600/400`);
  if (!img.ok) return null;
  const buf = Buffer.from(await img.arrayBuffer());
  const form = new FormData();
  form.append('file', new Blob([buf], { type: 'image/jpeg' }), `${seed}.jpg`);
  const res = await fetch(BASE + '/api/uploads', {
    method: 'POST', headers: { authorization: `Bearer ${token}` }, body: form,
  });
  if (!res.ok) return null;
  return (await res.json()).data.url;
}

async function main() {
  // The account you'll log in with.
  const demo = await reg('demo@hiww.test', 'Demo User', 'both');

  // Travelers + trips.
  const tara = await reg('tara@hiww.test', 'Tara Wong', 'traveler');
  const ken = await reg('ken@hiww.test', 'Ken Ito', 'traveler');
  const mei = await reg('mei@hiww.test', 'Mei Lin', 'traveler');

  const trips = [
    [tara, 'TH', 'JP', 'Bangkok', 'Tokyo', 3, 17, 10, 6, 'tokyo'],
    [ken, 'JP', 'TH', 'Osaka', 'Bangkok', 6, 13, 8, 5, 'osaka'],
    [mei, 'SG', 'KR', 'Singapore', 'Seoul', 9, 20, 12, 8, 'seoul'],
  ];
  for (const [u, dc, ac, dcity, acity, d1, d2, kg, items, seed] of trips) {
    const cover = await uploadStock(u.token, seed);
    await api('POST', '/api/trips', {
      token: u.token,
      body: {
        departure_country: dc, arrival_country: ac,
        departure_city: dcity, arrival_city: acity,
        departure_date: days(d1), return_date: days(d2),
        max_weight_kg: kg, max_items: items,
        title: `${dcity} → ${acity}`,
        ...(cover ? { cover_image_url: cover } : {}),
      },
    });
  }

  // Shoppers + wants.
  const sam = await reg('sam@hiww.test', 'Sam Park', 'shopper');
  const jo = await reg('jo@hiww.test', 'Jo Tan', 'shopper');
  const wants = [
    [sam, 'Nike Dunk Low Panda', 'US 9.5, brand new in box. Any Tokyo sneaker store.', 'JP', 'Tokyo', 'sneakers', '4200.00', 'sneaker'],
    [jo, 'Muji gel pens (x20)', 'Black 0.38mm, the 20-pack. Easy pickup at any Muji.', 'JP', null, 'other', '850.00', 'stationery'],
    [demo, 'Laneige Lip Sleeping Mask', 'Berry flavour, full size. From Olive Young in Seoul.', 'KR', 'Seoul', 'beauty', '650.00', 'beauty'],
    [sam, 'Tokyo Banana box', 'The classic 8-pack from Tokyo Station.', 'JP', 'Tokyo', 'food', '900.00', 'snacks'],
  ];
  for (const [u, title, desc, sc, scity, cat, budget, seed] of wants) {
    const image = await uploadStock(u.token, seed);
    await api('POST', '/api/requests', {
      token: u.token,
      body: {
        title, item_description: desc, source_country: sc,
        ...(scity ? { source_city: scity } : {}),
        category: cat, estimated_weight_kg: 1, budget,
        ...(image ? { image_url: image } : {}),
        need_by: days(30),
      },
    });
  }

  // One live offer on the demo user's want, so there's something to accept.
  const feed = await api('GET', '/api/discover/feed?type=wants', { token: tara.token });
  const demoWant = (await api('GET', '/api/requests/mine', { token: demo.token })).items[0];
  const tripForOffer = (await api('GET', '/api/trips/mine', { token: mei.token })).items[0];
  await api('POST', '/api/offers', {
    token: mei.token,
    body: {
      request_id: demoWant.id, trip_id: tripForOffer.id,
      quoted_price: '600.00', delivery_date: days(21),
    },
  });

  console.log('\n✅ Seeded.');
  console.log('   Log in:  demo@hiww.test  /  demo1234');
  console.log('   (all seeded accounts use the password demo1234)');
}

main().catch((e) => { console.error('❌', e); process.exit(1); });
