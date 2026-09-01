# Hiww — Manual-Money Pilot Runbook

This is the operating manual for running Hiww as a **manual-money pilot**: real
users, but you (the admin) move money by hand — bank transfer, PayPal, Wise,
whatever — and the software only tracks the *state* of each order. The automatic
payment engine is intentionally switched off (`MANUAL_MONEY_PILOT=true`).

Keep this document and your money spreadsheet next to each other. They are the
system of record for the pilot.

---

## 1. One-time setup

You need: Node.js 18+, PostgreSQL running locally, this repo.

```powershell
# from the project folder
npm install
Copy-Item .env.example .env      # then edit .env

# .env must have a real DATABASE_URL and a strong JWT_SECRET.
# Generate a secret with:
node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"

npm run db:setup                 # creates + migrates the database (DESTRUCTIVE)
npm run dev                      # starts the API on http://localhost:3000
```

Make yourself an admin (do this once, after you have registered your own
account through the app):

```powershell
npm run make-admin your-email@example.com
```

Only admins can confirm payments, resolve disputes, approve KYC, or flag users.
Keep the admin list to people you trust. To remove admin: `npm run make-admin someone@example.com -- --remove`.

---

## 2. How money works in the pilot

| Step | Who | What happens in software | What you do with real money |
|------|-----|--------------------------|------------------------------|
| Order accepted | shopper | order = `pending_payment` | nothing yet |
| Payment | **admin** | you call *confirm payment* → order = `confirmed` | **first** collect the shopper's payment into your account, **then** confirm |
| Shipped | traveler | order = `in_transit` | nothing |
| Received | shopper | order = `delivered` | nothing yet |
| Payout | **admin** | (no software step) | pay the traveler their quoted price **minus your platform fee**; record it |

**Golden rule:** never call *confirm payment* until the shopper's money is
actually in your account. Never pay a traveler until the order is `delivered`
(or a dispute says so).

### Money spreadsheet

Set this up before onboarding anyone: import `docs/money-tracker-template.csv`
into Google Sheets or Excel. Full instructions and the two rules that keep you
solvent are in **[MONEY-TRACKER.md](MONEY-TRACKER.md)**.

---

## 3. Daily operations

All commands below are PowerShell. Set these once per session:

```powershell
$api = "http://localhost:3000"
# Log in as your admin account to get a token:
$login = Invoke-RestMethod -Method Post -Uri "$api/api/auth/login" -ContentType application/json -Body (@{ email="your-email@example.com"; password="YOUR_PASSWORD" } | ConvertTo-Json)
$admin = @{ Authorization = "Bearer $($login.data.token)" }
```

### Approve a user's KYC

```powershell
# See who is waiting:
Invoke-RestMethod -Uri "$api/api/admin/reviews" -Headers $admin | ConvertTo-Json -Depth 6

# Approve (or 'rejected'):
Invoke-RestMethod -Method Post -Uri "$api/api/admin/users/USER_ID/kyc-review" -Headers $admin -ContentType application/json -Body (@{ status="approved"; note="Passport checked, matches profile" } | ConvertTo-Json)
```

### Confirm a payment (after the shopper's money has arrived)

```powershell
Invoke-RestMethod -Method Post -Uri "$api/api/payments/confirm" -Headers $admin -ContentType application/json -Body (@{ order_id="ORDER_ID"; payment_id="bank ref / Wise ID" } | ConvertTo-Json)
```

This moves the order to `confirmed`. It is safe to run twice — the second call
does nothing. Record the payment in your spreadsheet.

### Check an order's status

```powershell
Invoke-RestMethod -Uri "$api/api/orders/ORDER_ID" -Headers $admin | ConvertTo-Json -Depth 4
```

### Pay a traveler

There is no software step. When the order is `delivered`:
1. Confirm the order status is `delivered`.
2. Send the traveler their quoted price minus your fee.
3. Record `traveler paid` in the spreadsheet.

---

## 4. Handling a dispute

Either party opens a dispute in the app. To work it:

```powershell
# List open disputes:
Invoke-RestMethod -Uri "$api/api/admin/reviews" -Headers $admin | ConvertTo-Json -Depth 6

# After you have decided (talk to both sides, look at evidence):
Invoke-RestMethod -Method Post -Uri "$api/api/admin/disputes/DISPUTE_ID/resolve" -Headers $admin -ContentType application/json -Body (@{ status="resolved"; resolution="Refunded shopper 50% on 2026-09-05, Wise ref XYZ. Traveler notified." } | ConvertTo-Json)
```

Then **carry out the money decision by hand** (refund the shopper, pay the
traveler, or split) and write exactly what you did in the `resolution` text and
your spreadsheet. The software does not move any money when a dispute is
resolved.

### Evidence

```powershell
Invoke-RestMethod -Uri "$api/api/orders/ORDER_ID/evidence" -Headers $admin | ConvertTo-Json -Depth 4
```

---

## 5. If something looks wrong

| Symptom | What to do |
|---------|-----------|
| An order jumped to `confirmed` and you didn't do it | Check who your admins are (`SELECT email FROM users WHERE role='admin';`). Only admins can confirm. |
| A user says they can see someone else's data | Stop the pilot, write down exactly what they did, contact your engineer. |
| Server won't start, mentions `JWT_SECRET` | Your `.env` is missing a strong `JWT_SECRET`. Generate one (see setup). |
| You need to undo a code change | `git log --oneline` to find a good commit, then `git revert <commit>`. Never `git reset --hard` without a backup. |

---

## 6. What NOT to do during the pilot

- Do **not** set `MANUAL_MONEY_PILOT=false`. The automatic path is not built.
- Do **not** expose this server to the public internet yet (no HTTPS, no
  hardened hosting). Pilot users should reach it over a trusted network or a
  tunnel you control.
- Do **not** hand out admin access casually.
- Do **not** delete users — it also deletes their order history.
- Do **not** skip the money spreadsheet. The database does not track real cash.

---

## 7. Known limits (tracked for later, see `docs/CHANGES-2026-09.md`)

- No admin web UI — operations are API calls (this document).
- No real payment/KYC provider integration.
- No HTTPS / production hosting setup.
- Ledger/wallet balances in the database are **not** meaningful in the pilot.
- Passwords cannot be reset yet (no email flow) — re-create the account.
