# Money Tracker — how to use it

The database does **not** track real cash during the pilot. This spreadsheet is
your legal and financial source of truth. If it and the app ever disagree, the
spreadsheet wins and you investigate.

## Setup (5 minutes)

1. Open Google Sheets (or Excel).
2. File → Import → upload `docs/money-tracker-template.csv` → "Replace current sheet".
3. Delete the three `EXAMPLE` rows once you understand them.
4. Freeze the header row (View → Freeze → 1 row).
5. Share it only with people who need it. Keep a backup (Sheets keeps history automatically).

## The columns

| Column | Meaning |
|--------|---------|
| `order_id` | Copy from the app when an offer is accepted. |
| `date_accepted` | When the order was created. |
| `shopper_*`, `traveler_*` | Names + an email/phone you can actually reach them at. |
| `item`, `item_price` | What the traveler quoted for the goods. |
| `platform_fee` | Your cut. The app currently computes 8% of item price — check the order in the app and copy it, or set your own policy. |
| `shopper_owes_total` | `item_price + platform_fee`. This is what you invoice the shopper. |
| `shopper_paid_amount` / `_date` / `_ref` | What actually landed in your account, when, and the bank/Wise reference. |
| `payment_confirmed_in_app` | Y once you've run the *confirm payment* step. **Only mark Y after the money is really in your account.** |
| `order_status` | Copy from the app: `pending_payment` → `confirmed` → `in_transit` → `delivered`. |
| `traveler_payout_amount` | Normally `item_price` (the traveler gets their quote; your fee came from the shopper on top). Adjust for disputes. |
| `traveler_paid_*` | When and how you paid the traveler out. Only after `delivered` or a dispute decision. |
| `dispute` | yes/no. |
| `notes` | Everything else — especially the exact money movements for any dispute. |

## The two rules

1. **Money in before you confirm.** Never run *confirm payment* in the app until
   `shopper_paid_amount` is filled in from a real transaction.
2. **`delivered` before you pay out.** Never fill `traveler_paid_*` until
   `order_status` is `delivered` or a resolved dispute tells you what to pay.

## Monthly check (reconciliation)

Once a month, add up:

- **Money you're holding** = sum of `shopper_paid_amount` for orders where
  `traveler_paid_date` is blank.
- That number should equal the actual balance sitting in your account earmarked
  for Hiww orders. If it doesn't, find out why before onboarding anyone new.
- **Your revenue** = sum of `platform_fee` for `delivered` orders, minus any
  refunds you gave from your own pocket.
