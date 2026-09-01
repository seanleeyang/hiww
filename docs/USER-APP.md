# The shopper / traveler app

A single web page for your pilot users. Served by the same server as the API.

- **Users go to:** `http://localhost:3000/` (or `/app`)
- **You (operator) go to:** `http://localhost:3000/admin`

Right now it only runs on your machine — see "Getting it to users" below.

## What a user can do

**On sign-up** they pick: Shopper, Traveler, or Both. The menu adapts.

### Shopper
- Post a request (what they want bought, where, budget)
- See offers travelers make on it, accept one
- On the order: see payment instructions + amount + reference, tap
  **"I've sent the payment"**, then wait for you to confirm
- Once shipped: **Confirm I received it**
- Add photo links, open a dispute

### Traveler
- Post a trip (route, dates, spare capacity)
- Browse open requests, **Make an offer** (price + which trip + delivery date)
- See their offers and status
- On an accepted+paid order: **Mark as shipped**
- Add photo links

### Both
- Submit ID details for KYC (you approve them from the console)

## What it does NOT do yet

- **No card payments** — the shopper sees your bank/PromptPay details (set
  `PILOT_PAYMENT_INSTRUCTIONS` in `.env`) and pays manually; you confirm in the
  console when the money lands.
- **No photo upload** — users paste a link (Google Drive / Imgur). Real upload
  is a later phase.
- **No password reset, no email verification, no notifications** — later phases.
- **Traveler-initiated flow** (shopper pre-orders against a posted trip) is not
  built; the pilot runs the shopper-initiated flow (request → offer → accept).

## Set your payment instructions

Edit `.env` and add, e.g.:

```
PILOT_PAYMENT_INSTRUCTIONS=PromptPay 08x-xxx-xxxx (Hiww Co.) or Bangkok Bank 123-4-56789-0. Put the order reference in the transfer note.
```

Restart the server. Shoppers now see this on their payment screen.

## Getting it to users (not done yet)

The app is only reachable on your computer. To let a handful of pilot users in,
your engineer will set up a **private tunnel** (e.g. Cloudflare Tunnel) that
gives a temporary public URL you control. This is deliberately not automatic —
the app still has no HTTPS certificate of its own or hardened hosting, so it is
only for a small, short, supervised pilot.
