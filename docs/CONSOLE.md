# The Pilot Console — click, don't type

A simple web page for running the pilot. No Postman, no commands once it's set up.

## First time only

1. Double-click **`first-time-setup.bat`** — installs everything and creates an
   empty database. (Type `YES` when it asks.)
2. Double-click **`create-admin.bat`** — type an email and a password. This is
   your login for the console.

If a `.bat` file opens in a text editor instead of running, right-click it →
**Run** / **Open**, or from a terminal run the command inside it.

## Every day

1. Double-click **`start-hiww.bat`**.
2. A black window opens (that's the engine — leave it open) and after a few
   seconds your browser opens the console.
3. Log in with the email/password you made above.
4. When you're done, close the black window.

The console lives at **http://localhost:3000/admin** if you need the address.

## The pages

| Page | What it's for |
|------|---------------|
| **Dashboard** | Quick counts of what needs attention — open disputes, pending ID checks, flagged content, money owed. |
| **Disputes** | Reports from users. Write what you decided and click **Resolve**, or click **Cancel order & resolve** if the order itself needs to be cancelled — this is the one place that can actually cancel an order once it's underway. |
| **ID checks** | People waiting for ID approval. Approve or reject with a button. |
| **Flagged content** | Receipts and chat messages the automatic checks flagged. Clear the flag once you've looked. |
| **Orders** | Every order. Open one to see its full timeline and take action: confirm payment, cancel it, record a payout, or record a refund. |
| **Trips** / **Wants** | Every listing. Remove a problem post (does not touch any order already built on it). |
| **Offers** | The negotiation between a want and an order — read-only. |
| **Reviews** | Star ratings left after delivery. Hide anything abusive. |
| **Users** | Everyone registered. Approve/reject their ID, flag a risky account. |
| **Money** | What's owed in, owed out, and settled — payments, payouts, and refunds. |
| **Audit log** | Every action taken, for the record. |
| **Developer tools** | Click **Create a test order** to make a fake shopper, traveler and order so you can watch the whole flow — then open it from Orders and confirm its payment, cancel it, etc. |

## Important

- This runs **only on your computer**. Don't put it on the internet yet — it has
  no HTTPS or hosting protection. When you need pilot users to reach it, ask your
  engineer to set up a private tunnel.
- The console still does **not** move real money. It records decisions; you move
  the cash by hand and log it in your spreadsheet ([MONEY-TRACKER.md](MONEY-TRACKER.md)).
- "Developer tools" writes real rows into your database using `test-*@pilot.local`
  accounts. Run `first-time-setup.bat` again if you want a clean slate (it wipes
  everything).

## If something breaks

- **Browser says "can't connect"** — the engine window isn't ready yet, wait and
  refresh; or it crashed — check that window for a red error.
- **"This account is not an admin"** banner — run `create-admin.bat` again with
  the same email.
- **Need to undo a code change** — in a terminal: `git log --oneline`, then
  `git revert <the-commit-id>`.
