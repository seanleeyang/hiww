# Clicking through the API with Postman

This is the fastest "test by clicking" option — no frontend to build. Validated
end to end (all 35 requests pass).

## Setup (one time)

1. Install **Postman** (free): https://www.postman.com/downloads/
2. Start the API: `npm run dev`
3. In Postman: **Import** → drop in `postman-collection.json` from this repo.
4. The collection ships with sensible defaults (`base_url = http://localhost:3000`,
   emails, a shared password). Change them under the collection's **Variables**
   tab if you like.

## Run order

### Folder `A. First-time setup` — run top to bottom, once
Creates an admin, a shopper and a traveler and stores their login tokens
automatically.

**After "Register admin"**, run this once in a terminal (admin rights cannot be
granted over the API, on purpose):

```powershell
npm run make-admin admin@pilot.local
```

Then run **"Login admin"** again.

### Folder `B. Happy path` — run top to bottom
Pushes one order through every stage: approve KYC → shopper request → traveler
trip → offer → accept → **admin confirms payment** → shipped → received.
`order_id` and friends are captured as you go.

### Folder `C. Admin tools`
Review queue, ops metrics, open/resolve a dispute, flag a user, KYC review,
view a ledger. Run any of these any time after folder A.

### Folder `D. Browse / read`
List trips/requests/orders, submit KYC, upload evidence, notifications.

## Notes

- Tokens and IDs flow between requests via **collection variables** — you should
  never need to copy/paste a token or an ID.
- If a request 401s, your token expired (7 days) — re-run the matching "Login"
  request.
- If a request 403s with `ADMIN_REQUIRED`, you're using a non-admin token on an
  admin route, or you haven't run `npm run make-admin` yet.
- This talks to your **local** server only. Don't expose the server to the
  internet yet.

## Re-validate the collection any time

```powershell
npm run dev                      # in one terminal
npx newman run postman-collection.json   # in another (downloads newman first run)
```
