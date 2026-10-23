'use strict';

// ── Stripe Checkout + S3 Download Distribution ──────────────────────────────
//
// Handles:
//   POST /checkout/session   — creates a Stripe Checkout Session
//   POST /stripe-webhook     — receives payment confirmation from Stripe
//   GET  /download/:platform — generates a pre-signed S3 download URL
//
// Environment variables:
//   STRIPE_SECRET_KEY        — sk_live_... or sk_test_...
//   STRIPE_WEBHOOK_SECRET    — whsec_... (from Stripe Dashboard → Webhooks)
//   AWS_S3_DOWNLOADS_BUCKET  — bucket holding the app binaries
//   AWS_REGION               — defaults to us-east-1
//
// The download bucket is expected to have keys like:
//   vetviona/latest/vetviona-windows.msix
//   vetviona/latest/vetviona-macos.dmg
//   vetviona/latest/vetviona-linux.deb
//   vetviona/latest/vetviona-linux.snap
//   vetviona/latest/vetviona-linux.flatpak
//   vetviona/latest/vetviona-android.apk
//   vetviona/latest/vetviona-ios.ipa

const crypto = require('crypto');

const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY || '';
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';
const S3_DOWNLOADS_BUCKET = process.env.AWS_S3_DOWNLOADS_BUCKET || '';
const AWS_REGION = process.env.AWS_REGION || 'us-east-1';

// Price ID → license type mapping.  Updated when prices change in Stripe.
const PRICE_TO_LICENSE = {
  'price_1TS0Y10TDCV9HVSmaXs2os8t': 'android',
  'price_1TS0YD0TDCV9HVSmzMiccH2k': 'apple',
  'price_1TS0YJ0TDCV9HVSmuz4MNLaN': 'desktop',
  'price_1TMezH0TDCV9HVSmmL3TNeDA': 'bundle',
};

// Platform → S3 object key mapping.
const PLATFORM_KEYS = {
  'windows':  'vetviona/latest/vetviona-windows.msix',
  'macos':    'vetviona/latest/vetviona-macos.dmg',
  'linux-deb':'vetviona/latest/vetviona-linux.deb',
  'linux-snap':'vetviona/latest/vetviona-linux.snap',
  'linux-flatpak':'vetviona/latest/vetviona-linux.flatpak',
  'android':  'vetviona/latest/vetviona-android.apk',
};

// License type → which platforms the user can download.
const LICENSE_PLATFORMS = {
  'android': ['android'],
  'apple':   [], // iOS distributed via App Store, not direct download
  'desktop': ['windows', 'macos', 'linux-deb', 'linux-snap', 'linux-flatpak'],
  'bundle':  ['windows', 'macos', 'linux-deb', 'linux-snap', 'linux-flatpak', 'android'],
};

// ── Stripe helpers ──────────────────────────────────────────────────────────

let _stripe = null;
function getStripe() {
  if (_stripe) return _stripe;
  if (!STRIPE_SECRET_KEY) return null;
  try {
    const Stripe = require('stripe');
    _stripe = new Stripe(STRIPE_SECRET_KEY);
    return _stripe;
  } catch (e) {
    console.warn(`[stripe] stripe package unavailable: ${e.message}`);
    console.warn('[stripe] Run: npm install stripe');
    return null;
  }
}

// ── S3 pre-signed URL helper ────────────────────────────────────────────────

async function generateDownloadUrl(platform) {
  const key = PLATFORM_KEYS[platform];
  if (!key || !S3_DOWNLOADS_BUCKET) return null;
  try {
    const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');
    const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
    const s3 = new S3Client({ region: AWS_REGION });
    const command = new GetObjectCommand({
      Bucket: S3_DOWNLOADS_BUCKET,
      Key: key,
    });
    // URL valid for 1 hour.
    return await getSignedUrl(s3, command, { expiresIn: 3600 });
  } catch (e) {
    console.error(`[download] Failed to generate pre-signed URL: ${e.message}`);
    return null;
  }
}

// ── Fulfilled purchases store ───────────────────────────────────────────────
// In production this would be in the license DB.  For now we store fulfilled
// session IDs in memory + the license-db.json via the existing writeDb/readDb.

/**
 * Records a successful purchase in the license database.
 * Called from the webhook handler after payment confirmation.
 *
 * @param {object} db - The license database object (from readDb).
 * @param {string} email - Customer email from Stripe.
 * @param {string} licenseType - 'android' | 'apple' | 'desktop' | 'bundle'.
 * @param {string} sessionId - Stripe Checkout Session ID (for idempotency).
 * @returns {boolean} true if a new purchase was recorded, false if duplicate.
 */
function recordPurchase(db, email, licenseType, sessionId) {
  // Idempotency: skip if this session was already fulfilled.
  db.fulfilledSessions = db.fulfilledSessions || [];
  if (db.fulfilledSessions.includes(sessionId)) return false;

  const normalizedEmail = email.trim().toLowerCase();

  // Find or create the account.
  let account = db.accounts.find((a) => a.email === normalizedEmail);
  if (!account) {
    // Create a minimal account — the user can set a password later via the
    // app's "Claim License" flow.
    account = {
      id: crypto.randomUUID(),
      email: normalizedEmail,
      passwordSalt: '',
      passwordHash: '',
      emailVerified: false,
      licenses: { apple: false, android: false, desktop: false },
      giftedOut: { apple: null, android: null, desktop: null },
      devices: [],
      tokenVersion: 0,
      mfa: { enabled: false, secret: null, recoveryHashes: [] },
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    db.accounts.push(account);
  }

  // Grant the license(s).
  if (licenseType === 'bundle') {
    account.licenses.apple = true;
    account.licenses.android = true;
    account.licenses.desktop = true;
  } else if (account.licenses.hasOwnProperty(licenseType)) {
    account.licenses[licenseType] = true;
  }
  account.updatedAt = new Date().toISOString();

  db.fulfilledSessions.push(sessionId);
  return true;
}

// ── Route handlers ──────────────────────────────────────────────────────────

/**
 * POST /stripe-webhook
 *
 * Receives Stripe webhook events.  The only event we care about is
 * `checkout.session.completed` — when a customer finishes paying.
 */
async function handleWebhook(req, rawBody, db, writeDbFn) {
  const stripe = getStripe();
  if (!stripe) return { status: 503, body: { error: 'Stripe not configured.' } };

  const sig = req.headers['stripe-signature'];
  if (!sig || !STRIPE_WEBHOOK_SECRET) {
    return { status: 400, body: { error: 'Missing signature or webhook secret.' } };
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, sig, STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    console.error(`[stripe-webhook] Signature verification failed: ${err.message}`);
    return { status: 400, body: { error: 'Invalid signature.' } };
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const email = session.customer_details?.email || session.customer_email || '';
    const sessionId = session.id;

    // Determine which license was purchased from the line items.
    // Payment links embed the price in the session's line_items, but the
    // webhook payload only includes the session — we need to expand.
    let licenseType = 'desktop'; // fallback
    try {
      const fullSession = await stripe.checkout.sessions.retrieve(sessionId, {
        expand: ['line_items'],
      });
      const priceId = fullSession.line_items?.data?.[0]?.price?.id;
      if (priceId && PRICE_TO_LICENSE[priceId]) {
        licenseType = PRICE_TO_LICENSE[priceId];
      }
    } catch (e) {
      console.warn(`[stripe-webhook] Could not expand line_items: ${e.message}`);
    }

    if (email) {
      const isNew = recordPurchase(db, email, licenseType, sessionId);
      if (isNew) {
        await writeDbFn(db);
        console.log(`[stripe-webhook] License granted: ${licenseType} → ${email}`);
      }
    }
  }

  return { status: 200, body: { received: true } };
}

/**
 * GET /download/:platform
 *
 * Generates a pre-signed S3 URL for a paid user to download the app binary.
 * Requires a valid license (checked via email in query string + license DB).
 *
 * Query params:
 *   ?email=user@example.com&token=<session-token>
 *
 * In production, this should use the Bearer token auth from the license server.
 * For the initial launch, we accept email + check the license DB directly.
 */
async function handleDownload(platform, db, email) {
  if (!S3_DOWNLOADS_BUCKET) {
    return { status: 503, body: { error: 'Download service not configured.' } };
  }
  if (!platform || !PLATFORM_KEYS[platform]) {
    return {
      status: 400,
      body: {
        error: 'Invalid platform.',
        validPlatforms: Object.keys(PLATFORM_KEYS),
      },
    };
  }

  const normalizedEmail = (email || '').trim().toLowerCase();
  if (!normalizedEmail) {
    return { status: 401, body: { error: 'Email required.' } };
  }

  const account = db.accounts.find((a) => a.email === normalizedEmail);
  if (!account) {
    return { status: 403, body: { error: 'No license found for this email.' } };
  }

  // Check if the user's license covers this platform.
  const hasAccess = Object.entries(LICENSE_PLATFORMS).some(([licType, platforms]) => {
    if (!account.licenses[licType === 'bundle' ? 'desktop' : licType]) return false;
    // Bundle check: if they have all three, treat as bundle.
    if (licType === 'bundle') {
      return account.licenses.apple && account.licenses.android && account.licenses.desktop
        && platforms.includes(platform);
    }
    return platforms.includes(platform);
  });

  // Simpler check: desktop license covers all desktop platforms.
  const desktopPlatforms = ['windows', 'macos', 'linux-deb', 'linux-snap', 'linux-flatpak'];
  const canDownload =
    (account.licenses.desktop && desktopPlatforms.includes(platform)) ||
    (account.licenses.android && platform === 'android') ||
    hasAccess;

  if (!canDownload) {
    return { status: 403, body: { error: 'Your license does not cover this platform.' } };
  }

  const url = await generateDownloadUrl(platform);
  if (!url) {
    return { status: 503, body: { error: 'Download temporarily unavailable.' } };
  }

  return { status: 200, body: { url, platform, expiresIn: 3600 } };
}

module.exports = {
  handleWebhook,
  handleDownload,
  recordPurchase,
  PLATFORM_KEYS,
  PRICE_TO_LICENSE,
};
