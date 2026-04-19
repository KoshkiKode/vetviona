# Vetviona License Backend

This backend handles only:

- Vetviona paid-license account registration with **email verification**
- paid-license verification for **apple** (`ios`), **android** (`android`), and **desktop** (`windows`/`macos`/`linux`)
- reusable, **verifiable re-entry license codes** for reinstall/multi-device flows
- a hard cap of **15 computers/devices per license type** (configurable)
- **License gifting / transfer** — transfer a license to another account
- account license sync (entitlements + verified devices)
- password changes

It does **not** store genealogy data.

## Run

```bash
cd backend
node license_server.js
```

### Installing optional dependencies

```bash
# For real email delivery (SMTP):
npm install nodemailer

# For AWS S3 database storage (production):
npm install @aws-sdk/client-s3
```

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Path to local JSON database (dev only; ignored when S3 is configured) |
| `SMTP_HOST` | *(unset)* | SMTP server hostname. Leave unset for dev mode (tokens logged to console) |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for TLS on port 465 |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address |
| `MAX_DEVICES_PER_LICENSE` | `15` | Max verified devices/computers per license type |
| `LICENSE_KEY_SECRET` | *(auto-generated and persisted in DB)* | HMAC secret used to generate verifiable re-entry license codes |
| **`AWS_S3_BUCKET`** | *(unset)* | **S3 bucket name** — set this to enable S3 storage instead of the local file |
| `AWS_S3_KEY` | `vetviona/license-db.json` | S3 object key (path within the bucket) |
| `AWS_KMS_KEY_ID` | *(unset)* | KMS key ARN/alias for SSE-KMS encryption; leave unset to use SSE-S3 (AES-256) |
| `AWS_REGION` | `us-east-1` | AWS region where the S3 bucket lives |
| `AWS_ACCESS_KEY_ID` | *(IAM role / env)* | AWS access key (not needed when running on EC2/ECS/Lambda with an IAM role) |
| `AWS_SECRET_ACCESS_KEY` | *(IAM role / env)* | AWS secret key (same as above) |

**Dev mode (no SMTP):** verification codes and gift claim tokens are printed to the console **and** returned in API responses as `_devToken`.  Install nodemailer (`npm install nodemailer`) and set `SMTP_HOST` for real emails.

---

## AWS S3 Database Storage

In production the license database should be stored in an S3 bucket rather than a local file.  S3 gives you durability (11 nines), automatic at-rest encryption, versioning for point-in-time recovery, and access logging for audit trails — all without running a separate database server.

### 1. Create the S3 bucket

```bash
# Replace us-east-1 and my-vetviona-licenses with your values
aws s3api create-bucket \
  --bucket my-vetviona-licenses \
  --region us-east-1

# Block all public access (mandatory)
aws s3api put-public-access-block \
  --bucket my-vetviona-licenses \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,\
    BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable versioning (allows point-in-time recovery)
aws s3api put-bucket-versioning \
  --bucket my-vetviona-licenses \
  --versioning-configuration Status=Enabled

# Enable server-side access logging (audit trail)
aws s3api put-bucket-logging \
  --bucket my-vetviona-licenses \
  --bucket-logging-status '{
    "LoggingEnabled": {
      "TargetBucket": "my-vetviona-licenses",
      "TargetPrefix": "access-logs/"
    }
  }'

# Enforce HTTPS-only access
aws s3api put-bucket-policy \
  --bucket my-vetviona-licenses \
  --policy '{
    "Version": "2012-10-17",
    "Statement": [{
      "Sid": "DenyHTTP",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::my-vetviona-licenses",
        "arn:aws:s3:::my-vetviona-licenses/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }]
  }'
```

### 2. (Recommended) Create a KMS key for envelope encryption

```bash
# Create a symmetric KMS key
aws kms create-key \
  --description "Vetviona license database encryption key" \
  --key-usage ENCRYPT_DECRYPT \
  --query 'KeyMetadata.KeyId' --output text
# Note the returned KeyId (a UUID) or create an alias:
aws kms create-alias \
  --alias-name alias/vetviona-license-db \
  --target-key-id <KeyId>
```

Set `AWS_KMS_KEY_ID=alias/vetviona-license-db` in your environment.  Without a KMS key the object is still encrypted with SSE-S3 (AES-256 managed by AWS).

### 3. Create an IAM policy for the backend process

Attach this policy to the IAM role (EC2 instance profile / ECS task role / Lambda execution role) or to the IAM user whose `AWS_ACCESS_KEY_ID` you will export.  Grant only the minimum permissions needed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LicenseDbReadWrite",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-vetviona-licenses/vetviona/license-db.json"
    },
    {
      "Sid": "LicenseDbKms",
      "Effect": "Allow",
      "Action": [
        "kms:GenerateDataKey",
        "kms:Decrypt"
      ],
      "Resource": "arn:aws:kms:us-east-1:123456789012:key/<KeyId>"
    }
  ]
}
```

> **Do not grant `s3:DeleteObject`, `s3:ListBucket`, or `s3:*`** — the backend needs only GetObject and PutObject on the single key.

### 4. Configure the backend

```bash
# On your server / in your deployment environment:
export AWS_S3_BUCKET=my-vetviona-licenses
export AWS_S3_KEY=vetviona/license-db.json          # optional; this is the default
export AWS_KMS_KEY_ID=alias/vetviona-license-db    # optional but recommended
export AWS_REGION=us-east-1
export LICENSE_KEY_SECRET=<at-least-32-random-chars> # must survive restarts!

# If NOT using an IAM role, also set:
export AWS_ACCESS_KEY_ID=<your-key-id>
export AWS_SECRET_ACCESS_KEY=<your-secret-key>

npm install @aws-sdk/client-s3
node license_server.js
```

> **`LICENSE_KEY_SECRET`** must be set to a stable value of ≥ 32 characters when using S3.  In local-file mode the secret is auto-generated and persisted in the JSON file; in S3 mode there is no local file to persist it in, so an unset secret would change on every restart and invalidate all users' re-entry license codes.

### 5. Security checklist for production

- [ ] `AWS_S3_BUCKET` is set — S3 storage is active
- [ ] Bucket has "Block all public access" enabled
- [ ] HTTPS-only bucket policy is in place (see step 1)
- [ ] Bucket versioning is enabled (recovery from accidental writes)
- [ ] Access logging is enabled (audit trail)
- [ ] `AWS_KMS_KEY_ID` is set (SSE-KMS over SSE-S3)
- [ ] KMS key rotation is enabled (`aws kms enable-key-rotation --key-id <KeyId>`)
- [ ] IAM policy grants only `s3:GetObject` + `s3:PutObject` on the exact object key
- [ ] `LICENSE_KEY_SECRET` is set to a stable ≥ 32-char random value
- [ ] `ADMIN_SECRET` is set (protects voucher creation endpoint)
- [ ] `SMTP_HOST` is set (real email delivery instead of dev console logging)

---

## Endpoints

- `GET /health`
- `POST /v1/account/register`
- `POST /v1/account/verify-email`
- `POST /v1/account/resend-verification`
- `POST /v1/account/change-password`
- `POST /v1/account/sync`
- `POST /v1/license/verify`
- `POST /v1/license/gift/initiate`
- `POST /v1/license/gift/claim`
- `POST /v1/license/gift/cancel`
- `POST /v1/license/voucher/create` *(admin-protected)*

### Register account

```bash
curl -X POST http://127.0.0.1:8080/v1/account/register \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appleLicense":true,
    "androidLicense":true,
    "desktopLicense":true
  }'
```

Response includes `_devToken` (dev mode) for the email verification code.

### Verify account email

```bash
curl -X POST http://127.0.0.1:8080/v1/account/verify-email \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","token":"ABCD1234"}'
```

### Resend verification email

```bash
curl -X POST http://127.0.0.1:8080/v1/account/resend-verification \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!"}'
```

### Change password

```bash
curl -X POST http://127.0.0.1:8080/v1/account/change-password \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "currentPassword":"ChangeMe123!",
    "newPassword":"BetterPassword!1"
  }'
```

### Verify a paid app install

`appType` must be `"apple"`, `"android"`, or `"desktop"`.

Authenticate with either:
- `email` + `password`, or
- `email` + `licenseCode` (re-entry code from a prior successful verification/sync).

```bash
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appType":"desktop",
    "os":"linux",
    "deviceId":"example-device-1",
    "appVersion":"1.0.0"
  }'
```

Or by reusable re-entry code:

```bash
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "licenseCode":"DES-ABCD-EF12-3456-7890-ABCD-EF12",
    "appType":"desktop",
    "os":"linux",
    "deviceId":"example-device-2",
    "appVersion":"1.0.0"
  }'
```

Successful verification responses include:
- `reentryLicenseCodes` (per active license type; reusable/verifiable)
- `deviceLimitPerLicense` (default `15`)
- `devicesUsedForLicense` (count used for the verified `appType`)

### Create vouchers (admin — "buy for others")

Vouchers are open gift tokens — any authenticated account can redeem them.
Use this to sell/distribute license codes without tying them to a specific email.

Protect with `ADMIN_SECRET` env var. In dev mode the secret is printed at startup.

```bash
# Create 3 desktop vouchers (send confirmation to purchaser@example.com)
curl -X POST http://127.0.0.1:8080/v1/license/voucher/create \
  -H 'Content-Type: application/json' \
  -d '{
    "adminSecret": "<your-admin-secret>",
    "licenseType": "desktop",
    "quantity": 3,
    "fromEmail": "purchaser@example.com",
    "notes": "Order #1234"
  }'
```

Response: `{ ok: true, vouchers: [{ id, token, licenseType, expiresAt }, ...] }`

The purchaser receives a confirmation email listing all tokens.
Share each token with the intended recipient — they can redeem it in the app
under **Settings → License Account → Claim a License Gift**.

```bash
# Redeem a voucher (any authenticated account)
curl -X POST http://127.0.0.1:8080/v1/license/gift/claim \
  -H 'Content-Type: application/json' \
  -d '{"email":"recipient@example.com","password":"MyPassword!","token":"ABCD1234"}'
```


Transfers one of your licenses to another email address.  Requires email verification.
The license is put in escrow — the sender cannot use it until the gift is claimed or cancelled.

```bash
curl -X POST http://127.0.0.1:8080/v1/license/gift/initiate \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "licenseType":"apple",
    "toEmail":"recipient@example.com"
  }'
```

### Claim a gift

The recipient authenticates and claims by gift ID (from their sync response) or by the claim token (from the email they received).

```bash
# Claim by token
curl -X POST http://127.0.0.1:8080/v1/license/gift/claim \
  -H 'Content-Type: application/json' \
  -d '{"email":"recipient@example.com","password":"MyPassword!","token":"ABCD1234"}'

# Claim by gift ID
curl -X POST http://127.0.0.1:8080/v1/license/gift/claim \
  -H 'Content-Type: application/json' \
  -d '{"email":"recipient@example.com","password":"MyPassword!","giftId":"<uuid>"}'
```

### Cancel a gift (sender)

```bash
curl -X POST http://127.0.0.1:8080/v1/license/gift/cancel \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!","licenseType":"apple"}'
```

### Sync account licenses/devices

```bash
curl -X POST http://127.0.0.1:8080/v1/account/sync \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!"}'
```

## App integration

Set the Flutter app backend URL with:

```bash
--dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8080
```

Paid tiers require one successful backend verification before the app can open.
License transfers are accessible in-app via **Settings → Vetviona License Account → Manage License Account**.
