# Payment & KYC Provider Outreach — playbook

You do **not** need any of this to run the manual pilot. Start it now anyway,
because approval takes 1–3 months and it's the long pole before Hiww can move
money automatically.

There are three workstreams. Do them in parallel.

---

## Your situation: Thailand company, mostly intra-Asia (buy in JP/KR → deliver to TH/SEA)

**Legal (Workstream A):** the regulator is the **Bank of Thailand (BOT)** under
the Payment Systems Act B.E. 2560. Holding shopper funds and paying travelers
most likely needs a BOT licence (e-Money / money-transfer / payment-account
issuing) **or** operating under a licensed partner's licence. Thai firms that do
this work: Tilleke & Gibbins, Baker McKenzie (Bangkok), Chandler MHM, or a
fintech boutique. Book one consult and ask the question in Workstream A.

**First payment calls, in order:**
1. **Opn (Omise)** — Thailand-HQ, best local collection (PromptPay, Thai cards,
   bank transfer), also has Japan. You already reference it in the code.
2. **2C2P** — Bangkok-HQ, SE-Asia-wide, does disbursements.
3. **Rapyd** — "collect + hold in a wallet + disburse" model fits this exactly;
   good payout coverage to Japan/Korea/SEA.
4. (Backup) **Airwallex** or **Wise Platform** for the cross-border payout leg to
   travelers in JP/KR, paired with a Thai collection method.

**KYC:**
- **NDID** for verifying **Thai shoppers** — bank-backed, very strong, Thailand only.
- **Sumsub** for **travelers** in Japan/Korea/elsewhere (good Asia coverage), or
  let the payment provider KYC the travelers if they offer it.

---

## Workstream A — the legal question (do this first, ~1 week, costs a bit)

Hiww takes a buyer's money, holds it, and later pays a third party (the
traveler). In almost every country that is a **regulated activity** ("payment
services", "e-money", "escrow"). You usually cannot do it legally on your own
bank account.

**Action:** book one paid consultation (1–2 hours) with a fintech/payments
lawyer in the country where Hiww is or will be incorporated. Ask exactly this:

> "I'm building a marketplace where a shopper pays us, we hold the funds, and we
> pay a traveler after delivery is confirmed. What licence do I need, and which
> payment providers let me operate under *their* licence instead of getting my
> own? Are there volume or time-limited exemptions for a small pilot?"

The answer decides everything below. Most likely outcome: you partner with a
payment provider who is the licensed party, and you never touch the money
directly.

---

## Workstream B — payment provider (email 3–4 this week)

You need a provider that does **all three** of:

1. **Collect** money from the shopper (card / bank transfer / local methods).
2. **Hold** it (escrow / wallet / delayed payout).
3. **Pay out** to the traveler, often **cross-border**, after your signal.

This feature set is called **"marketplace payments"**, **"split payments"**,
**"platform payments"** or **"managed payouts"**. A plain checkout provider is
not enough.

### Shortlist by situation

| Your situation | Try first |
|----------------|-----------|
| Based in / focused on Thailand or SE Asia | **Opn (Omise)**, **2C2P**, **Rapyd** |
| Cross-border APAC, multi-currency | **Airwallex**, **Rapyd**, **Wise Platform** (+ a collection method) |
| US / EU / global, want best docs | **Stripe Connect**, **Adyen for Platforms** |
| Emerging markets, want KYC bundled in | **Rapyd**, **Sumsub + a PSP** |

(You already referenced **Opn** in the codebase — make that call #1.)

### What to send them

> Subject: Marketplace payments for a cross-border shopping platform — [Hiww]
>
> Hi [name / team],
>
> I run Hiww, a peer-to-peer cross-border shopping marketplace. A shopper
> requests an item from abroad; a traveler buys it and hand-carries it; we hold
> the shopper's payment and release it to the traveler once delivery is
> confirmed (or per a dispute outcome).
>
> I'm looking for a payments partner that can:
> - collect payment from shoppers in [countries],
> - hold funds until we trigger release,
> - pay out to travelers in [countries], including cross-border,
> - handle the seller/traveler KYC and the regulatory licensing so we don't
>   need our own licence.
>
> Current stage: pre-launch, running a manual pilot. Expected first 3 months:
> roughly [N] transactions/month, average value [$X].
>
> Can we set up 30 minutes to see if this fits? What do you need from us to
> start onboarding?
>
> Thanks,
> [you]

### Questions to judge their answers

- Do we ever hold or touch customer funds, or do you? (You want: *they* do.)
- Do we need our own payment/e-money licence with your product? (You want: no.)
- Which countries can we **collect** from? Pay **out** to?
- How long from "release" to money in the traveler's account?
- Do you KYC the travelers, or do we?
- All-in fees: collection %, payout fee, FX margin, chargeback fee, monthly minimum?
- Sandbox available before signing? Webhooks for payment + payout status?
- How long does onboarding/approval take?

---

## Workstream C — identity / KYC provider (email 2, only if not bundled)

If a payment provider in Workstream B already does traveler KYC, you may only
need identity checks for **shoppers** (lower risk) — or none for the pilot.

| Provider | Good for |
|----------|----------|
| **Sumsub** | Global, strong in emerging markets, all-in-one (ID + liveness + AML screening) |
| **Onfido** | Global, document + face match |
| **Persona** | Flexible flows, good API, US/global |
| **Veriff** | Global, fast integration |
| **NDID** | Thai users specifically — bank-backed national digital ID (Thailand only) |

Ask them: coverage for your countries, price per verification, pass rates in
your markets, sandbox, and whether they do ongoing AML/sanctions screening.

---

## This week — checklist

- [ ] Book the lawyer consult (Workstream A).
- [ ] Email Opn + 2 other payment providers from the shortlist (Workstream B).
- [ ] Note in your calendar to chase non-responders in 1 week.
- [ ] Keep running the manual pilot — none of the above blocks it.

When a provider is chosen and the sandbox credentials arrive, that's when your
engineer wires it into `src/services/providers/` (the code already has the slots).
