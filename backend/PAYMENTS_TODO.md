# Payments and licensing — backburner notes

Payments (Stripe checkout, paid downloads, gifting/vouchers) are
intentionally **deprioritized** while app quality and core data-integrity
work (see `PROJECT_STATUS.md`) gets attention first. This document tracks
the open items so nothing gets lost in the meantime. Nothing here blocks
app development; it only needs to be revisited before payments go live
for real customers.

## Why this file exists

`backend/lib/stripe_checkout.js` and `backend/license_server.js` already
implement a working Stripe + S3-compatible download flow, including the
security fixes from the most recent audit (payment_status verification,
price-to-license mapping, squatter-account credential stripping). It is
functional, but not "done" — the items below are known gaps or decisions
that should be revisited before this is relied on for real revenue.

## Open items

1. **Stripe SDK major-version upgrade.** `package.json` pins
   `stripe: ^17.0.0`; the latest published major is `23.x`. This is a
   multi-major-version jump with breaking API changes (see Stripe's
   migration guides for v18–v23). Do not bump blindly — budget time to
   read the changelogs and re-test checkout/webhook flows end-to-end
   before upgrading.
2. **Webhook delivery and retries.** Confirm the webhook handler is
   idempotent under Stripe's at-least-once retry semantics, and add
   explicit tests for duplicate `checkout.session.completed` deliveries.
3. **`PRICE_TO_LICENSE` map maintenance.** The mapping from Stripe price
   IDs to license tiers lives in `stripe_checkout.js` and must be kept in
   sync by hand whenever pricing changes in the Stripe dashboard. Consider
   adding a startup check that fails loudly if a configured price ID is
   missing from the map (today an unmapped price safely falls back to no
   license, per the prior security fix, but it should also be observable
   via logs/alerts).
4. **Paid binary distribution via S3.** Real paid downloads need
   `S3_DOWNLOADS_BUCKET` (and friends: `S3_REGION`/`S3_ENDPOINT`/
   `S3_ACCESS_KEY_ID`/`S3_SECRET_ACCESS_KEY`) configured against a real
   self-hosted MinIO instance (or another S3-compatible provider) per
   `SERVER_SETUP.md` / `wiki/Deploy.md`. This is not yet provisioned
   anywhere.
5. **Squatter/pre-registration edge case.** The current fix strips
   credentials from an unverified pre-registered account when a Stripe
   purchase later fulfills that email, which closes the original
   account-squatting exploit. A remaining nuance: if the *legitimate*
   buyer had started (but not finished) email verification on their own
   account before someone else squatted the email, their in-progress
   verification state is also cleared by this fix. This is an acceptable
   trade-off (favors closing the exploit over preserving an edge-case
   verification token) but is worth a UX pass — e.g. a "your previous
   verification was reset, check your email again" notice — once payments
   come off the backburner.
6. **One deployment contract.** `PROJECT_STATUS.md` P0 item 5 calls for
   reconciling Stripe, account licenses, webhook retries, download
   authorization, and object storage configuration into a single
   documented deployment contract. This file is a start, but the full
   reconciliation (a single doc or runbook an operator can follow
   end-to-end) is still open.

## Not open items (already handled)

- Free-license registration no longer trusts client-supplied flags
  (closed in the prior security pass).
- Stripe `payment_status` is checked before fulfillment.
- Downloads require a verified bearer session token; email query
  parameters are not accepted as authorization.
- S3/MinIO credentials are read from generic `S3_*` env vars, not
  AWS-branded ones — see `SERVER_SETUP.md` for the canonical self-hosted
  MinIO setup. AWS itself is not a dependency of this project.
