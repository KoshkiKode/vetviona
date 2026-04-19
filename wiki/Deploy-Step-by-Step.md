# Step-by-Step Deployment Guide

This guide walks you through a **complete first-time production deployment** of Vetviona from a fresh AWS account.
By the end you will have:

- A hardened S3 bucket storing the license database
- A KMS key encrypting it at rest
- An EC2 server running the license backend over HTTPS behind Caddy
- SES configured for real transactional email
- All three app tiers built and pointed at the live backend

> **Already running?** Use this doc as a reference checklist — jump to any section.

---

## Prerequisites

Have these ready before you start:

| Tool | Install / docs |
|------|---------------|
| AWS account with admin access | [aws.amazon.com](https://aws.amazon.com) |
| AWS CLI ≥ 2.x configured with admin credentials | `aws configure` |
| Node.js 18+ on your dev machine | [nodejs.org](https://nodejs.org) |
| Flutter SDK ≥ 3.0 (stable) | [flutter.dev](https://flutter.dev/docs/get-started/install) |
| Git | `git --version` |
| A domain name (already in Route 53 or pointing to AWS) | Your domain registrar |
| SSH key pair | `ssh-keygen -t ed25519` if you don't have one |

---

## Part 1 — AWS Infrastructure

### Step 1 — Choose a region

Pick the AWS region closest to your users and use it consistently in every command below.

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account: $AWS_ACCOUNT_ID  Region: $AWS_REGION"
```

---

### Step 2 — Create the license database S3 bucket

The license database is a single JSON object in S3.  No public access — ever.

```bash
export BUCKET=vetviona-licenses
```

**Create the bucket** (omit `--create-bucket-configuration` if your region is `us-east-1`):
```bash
aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION" --create-bucket-configuration LocationConstraint="$AWS_REGION"
```

**Block all public access:**
```bash
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

**Enable versioning** (point-in-time recovery):
```bash
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
```

**Enable access logging** (audit trail):
```bash
aws s3api put-bucket-logging --bucket "$BUCKET" --bucket-logging-status '{"LoggingEnabled":{"TargetBucket":"'"$BUCKET"'","TargetPrefix":"access-logs/"}}'
```

**Enforce HTTPS-only:**
```bash
aws s3api put-bucket-policy --bucket "$BUCKET" --policy '{"Version":"2012-10-17","Statement":[{"Sid":"DenyHTTP","Effect":"Deny","Principal":"*","Action":"s3:*","Resource":["arn:aws:s3:::'"$BUCKET"'","arn:aws:s3:::'"$BUCKET"'/*"],"Condition":{"Bool":{"aws:SecureTransport":"false"}}}]}'
```

✅ Verify: `aws s3api get-bucket-versioning --bucket "$BUCKET"` should return `Status: Enabled`.

---

### Step 3 — Create a KMS encryption key

This key encrypts the license database object at rest with SSE-KMS (envelope encryption — stronger than the default SSE-S3).

**Create the key:**
```bash
KEY_ID=$(aws kms create-key --description "Vetviona license DB encryption key" --key-usage ENCRYPT_DECRYPT --region "$AWS_REGION" --query KeyMetadata.KeyId --output text) && echo "KMS Key ID: $KEY_ID"
```

**Create a friendly alias:**
```bash
aws kms create-alias --alias-name alias/vetviona-license-db --target-key-id "$KEY_ID" --region "$AWS_REGION"
```

**Enable automatic annual key rotation:**
```bash
aws kms enable-key-rotation --key-id "$KEY_ID" --region "$AWS_REGION"
```

✅ Verify: `aws kms describe-key --key-id alias/vetviona-license-db --region "$AWS_REGION"` shows `KeyState: Enabled`.

---

### Step 4 — Create an IAM role for the EC2 server

The backend server will use an EC2 instance profile instead of hardcoded credentials.  This is the recommended approach — you never handle AWS keys manually.

**Create the role:**
```bash
aws iam create-role --role-name VetvionaLicenseBackend --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
```

**Attach the minimal S3 + KMS policy:**
```bash
aws iam put-role-policy --role-name VetvionaLicenseBackend --policy-name LicenseDbAccess --policy-document '{"Version":"2012-10-17","Statement":[{"Sid":"LicenseDbReadWrite","Effect":"Allow","Action":["s3:GetObject","s3:PutObject"],"Resource":"arn:aws:s3:::'"$BUCKET"'/vetviona/license-db.json"},{"Sid":"LicenseDbKms","Effect":"Allow","Action":["kms:GenerateDataKey","kms:Decrypt"],"Resource":"arn:aws:kms:'"$AWS_REGION"':'"$AWS_ACCOUNT_ID"':key/'"$KEY_ID"'"}]}'
```

**Create an instance profile and attach the role:**
```bash
aws iam create-instance-profile --instance-profile-name VetvionaLicenseBackend
aws iam add-role-to-instance-profile --instance-profile-name VetvionaLicenseBackend --role-name VetvionaLicenseBackend
```

---

### Step 5 — Set up Amazon SES for transactional email

The backend sends email for account verification, license gifts, and vouchers.

**a. Verify your sending domain**

```bash
export MAIL_DOMAIN=vetviona.yourdomain.com
aws ses verify-domain-identity --domain "$MAIL_DOMAIN" --region "$AWS_REGION"
```

AWS will return a TXT verification token.  Add it to your domain's DNS as instructed in the console (**SES → Verified identities**).  Wait for status to become `Verified` (usually a few minutes).

**b. Request production access** (remove the SES sandbox)

By default SES is in sandbox mode — you can only send to verified addresses.  To send to real customers, submit a "Request production access" form in the AWS console under **SES → Account dashboard**.  Approval usually takes a few hours.

**c. Create SMTP credentials**

```bash
aws iam create-user --user-name vetviona-ses-smtp
aws iam attach-user-policy --user-name vetviona-ses-smtp --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess
```

Then in the AWS console: **SES → SMTP settings → Create SMTP credentials**.  Note the username and password — you only see them once.

> **SES SMTP endpoint** for your region: `email-smtp.<region>.amazonaws.com`  
> **Port:** 587 (STARTTLS) or 465 (TLS)

---

### Step 6 — Launch an EC2 instance

A `t3.micro` is more than sufficient for the license backend.

**Find the latest Amazon Linux 2023 AMI for your region:**
```bash
AMI_ID=$(aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*-x86_64" "Name=state,Values=available" --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" --output text --region "$AWS_REGION") && echo "AMI: $AMI_ID"
```

**Create a security group:**
```bash
SG_ID=$(aws ec2 create-security-group --group-name vetviona-backend-sg --description "Vetviona license backend" --query GroupId --output text) && echo "SG: $SG_ID"
```

**Allow SSH (your IP only), HTTP, and HTTPS:**
```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)/32
aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=$MY_IP}]" "IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp=0.0.0.0/0}]" "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0}]"
```

**Launch the instance** (replace `<your-key-pair-name>`):
```bash
INSTANCE_ID=$(aws ec2 run-instances --image-id "$AMI_ID" --instance-type t3.micro --key-name <your-key-pair-name> --security-group-ids "$SG_ID" --iam-instance-profile Name=VetvionaLicenseBackend --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=vetviona-backend}]' --query Instances[0].InstanceId --output text) && echo "Instance: $INSTANCE_ID"
```

**Get the public IP:**
```bash
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
```

✅ Point your domain's A record at this IP before continuing (needed for TLS cert).

---

## Part 2 — Server Setup

SSH into the server:

```bash
ssh -i ~/.ssh/your-key.pem ec2-user@<public-ip>
```

### Step 7 — Install Node.js and dependencies

```bash
# Install Node.js 22 (LTS) via NodeSource
curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -
sudo dnf install -y nodejs git

node --version   # should be 22.x
npm  --version
```

---

### Step 8 — Clone the repo and install backend deps

```bash
git clone https://github.com/KoshkiKode/vetviona.git /opt/vetviona
cd /opt/vetviona/backend
npm install @aws-sdk/client-s3
npm install nodemailer@^7.0.11
```

---

### Step 9 — Create the environment file

Generate the two required secrets first:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
node -e "console.log(require('crypto').randomBytes(8).toString('hex'))"
```

Create `/opt/vetviona/backend/.env` — **mode 600, root-owned**:

```bash
sudo tee /opt/vetviona/backend/.env > /dev/null << 'EOF'
PORT=3000
AWS_S3_BUCKET=vetviona-licenses
AWS_S3_KEY=vetviona/license-db.json
AWS_KMS_KEY_ID=alias/vetviona-license-db
AWS_REGION=us-east-1

LICENSE_KEY_SECRET=<paste-64-hex-chars-from-above>
ADMIN_SECRET=<paste-16-hex-chars-from-above>
MAX_DEVICES_PER_LICENSE=15

SMTP_HOST=email-smtp.us-east-1.amazonaws.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=<ses-smtp-username>
SMTP_PASS=<ses-smtp-password>
EMAIL_FROM=Vetviona <noreply@vetviona.yourdomain.com>
EOF
sudo chmod 600 /opt/vetviona/backend/.env
```

> **Never commit `.env` to git.** It is already in `.gitignore`.

---

### Step 10 — Create a systemd service

```bash
sudo tee /etc/systemd/system/vetviona-backend.service > /dev/null << 'EOF'
[Unit]
Description=Vetviona License Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/vetviona/backend
EnvironmentFile=/opt/vetviona/backend/.env
ExecStart=/usr/bin/node license_server.js
Restart=on-failure
RestartSec=5
User=ec2-user
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vetviona-backend
sudo systemctl start  vetviona-backend
sudo systemctl status vetviona-backend
```

✅ Check logs: `sudo journalctl -u vetviona-backend -f`  
You should see: `License database: s3://vetviona-licenses/vetviona/license-db.json (us-east-1) encryption=SSE-KMS`

---

### Step 11 — Install Caddy as a reverse proxy with automatic TLS

Caddy handles HTTPS automatically via Let's Encrypt — no certificate management needed.

```bash
sudo dnf install -y 'dnf-command(copr)'
sudo dnf copr enable @caddy/caddy -y
sudo dnf install -y caddy

sudo tee /etc/caddy/Caddyfile > /dev/null << EOF
license.yourdomain.com {
    reverse_proxy localhost:3000
}
EOF

sudo systemctl enable caddy
sudo systemctl start  caddy
sudo systemctl status caddy
```

Caddy will automatically obtain and renew a TLS certificate for your domain.

✅ Test: `curl https://license.yourdomain.com/health`  
Expected: `{"ok":true,"status":"healthy","emailMode":"smtp"}`

---

## Part 3 — Build the Apps

Run these commands on your **dev machine** (not the server).

```bash
cd /path/to/vetviona/app
flutter pub get
```

### Step 12 — Build Mobile Free (iOS + Android)

The free tier requires no backend URL — it works entirely offline.

```bash
# Android APK
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

### Step 13 — Build Mobile Paid (iOS + Android)

```bash
flutter build apk --release --dart-define=MOBILE_PAID=true --dart-define=LICENSE_BACKEND_URL=https://license.yourdomain.com
flutter build ios --release --dart-define=MOBILE_PAID=true --dart-define=LICENSE_BACKEND_URL=https://license.yourdomain.com
```

---

### Step 14 — Build Desktop Pro (Windows / macOS / Linux)

```bash
flutter build windows --release --dart-define=PAID=true --dart-define=LICENSE_BACKEND_URL=https://license.yourdomain.com
flutter build macos   --release --dart-define=PAID=true --dart-define=LICENSE_BACKEND_URL=https://license.yourdomain.com
flutter build linux   --release --dart-define=PAID=true --dart-define=LICENSE_BACKEND_URL=https://license.yourdomain.com
```

> Desktop builds **without** `--dart-define=PAID=true` show a lock screen at startup.

---

## Part 4 — Smoke Test

Run these `curl` commands against the live server to confirm everything is wired up correctly.

### Step 15 — Health check

```bash
curl https://license.yourdomain.com/health
# Expected: {"ok":true,"status":"healthy","emailMode":"smtp"}
```

### Step 16 — Register a test account

```bash
curl -s -X POST https://license.yourdomain.com/v1/account/register -H 'Content-Type: application/json' -d '{"email":"test@example.com","password":"TestPassword123!","desktopLicense":true}' | jq .
```

Expected: `{"ok":true,"account":{...}}` — check your test inbox for a verification email.

### Step 17 — Verify the S3 object was created

```bash
aws s3api head-object --bucket vetviona-licenses --key vetviona/license-db.json --region "$AWS_REGION"
```

Expected: 200 response with `ServerSideEncryption: aws:kms`.

### Step 18 — Verify email arrived and confirm it

Read the verification token from the email (subject: "Verify your Vetviona account email").  If SMTP is still being configured, grab it from the server log instead:

```bash
sudo journalctl -u vetviona-backend --since "5 minutes ago" | grep "\[email"
```

Then confirm the address (replace `<TOKEN>`):

```bash
curl -s -X POST https://license.yourdomain.com/v1/account/verify-email -H 'Content-Type: application/json' -d '{"email":"test@example.com","token":"<TOKEN>"}' | jq .
```

Expected: `{"ok":true,"message":"Email verified successfully."}`

### Step 19 — Create a test voucher (admin)

Replace `<ADMIN_SECRET>` with the value from your `.env` file:

```bash
curl -s -X POST https://license.yourdomain.com/v1/license/voucher/create -H 'Content-Type: application/json' -d '{"adminSecret":"<ADMIN_SECRET>","licenseType":"desktop","quantity":1,"notes":"smoke-test"}' | jq .
```

Expected: `{"ok":true,"vouchers":[{"id":"...","token":"XXXXXXXX",...}]}`

### Step 20 — Run the app and verify the license

Launch a desktop build pointing at the live backend, log in, and verify you see:

- ✅ EULA screen on first launch (tap **Accept**)
- ✅ License account screen available in **Settings → Vetviona License Account**
- ✅ Entitlements show `desktop: true` after verification

---

## Part 5 — Go-Live Checklist

Work through this before announcing the product:

### AWS infrastructure

- [ ] S3 bucket "Block all public access" is enabled
- [ ] S3 HTTPS-only bucket policy is in place
- [ ] S3 bucket versioning is enabled
- [ ] S3 access logging is enabled
- [ ] KMS key created with `alias/vetviona-license-db`
- [ ] KMS annual key rotation enabled
- [ ] EC2 instance profile grants only `s3:GetObject` + `s3:PutObject` on the single key
- [ ] SES domain identity is verified and production access approved

### Backend server

- [ ] `LICENSE_KEY_SECRET` set to a stable ≥ 32-char random value (never changes)
- [ ] `ADMIN_SECRET` set (not the dev auto-generated value)
- [ ] `SMTP_HOST` set — `emailMode` in `/health` response is `smtp` not `dev-console`
- [ ] Server is running as a non-root user via systemd
- [ ] `.env` file is `chmod 600`
- [ ] Backend is reachable only via HTTPS (Caddy / your reverse proxy handles termination)
- [ ] `/health` returns `{"ok":true}` over HTTPS
- [ ] Server logs show `encryption=SSE-KMS` in the database line

### App builds

- [ ] `LICENSE_BACKEND_URL` points to `https://license.yourdomain.com` (not `localhost`)
- [ ] Mobile Free builds have **no** `LICENSE_BACKEND_URL` or `MOBILE_PAID` flags
- [ ] Mobile Paid builds have `--dart-define=MOBILE_PAID=true`
- [ ] Desktop Pro builds have `--dart-define=PAID=true`
- [ ] EULA accepted gate works on first launch (fresh install / cleared storage)
- [ ] License verification succeeds end-to-end (register → verify email → verify license)
- [ ] Re-entry license code works on a second device without password

---

## Ongoing Operations

### View server logs

```bash
sudo journalctl -u vetviona-backend -f        # live tail
sudo journalctl -u vetviona-backend --since today
```

### Restart the backend after a code update

```bash
cd /opt/vetviona
git pull
sudo systemctl restart vetviona-backend
```

### Recover from a bad license DB write (S3 versioning)

**List recent versions of the database object:**
```bash
aws s3api list-object-versions --bucket vetviona-licenses --prefix vetviona/license-db.json --region "$AWS_REGION" | jq '.Versions[] | {VersionId, LastModified}'
```

**Restore a specific version** (replace `<VersionId>`):
```bash
aws s3api copy-object --bucket vetviona-licenses --copy-source "vetviona-licenses/vetviona/license-db.json?versionId=<VersionId>" --key vetviona/license-db.json --server-side-encryption aws:kms --ssekms-key-id alias/vetviona-license-db --region "$AWS_REGION"
```

### Rotate ADMIN_SECRET or LICENSE_KEY_SECRET

> ⚠️ **Rotating `LICENSE_KEY_SECRET` invalidates all existing re-entry license codes.** Users will need to log in with their password once to get a new code. Only rotate if the secret is compromised.

1. Generate a new secret: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`
2. Update the value in `/opt/vetviona/backend/.env`
3. Restart: `sudo systemctl restart vetviona-backend`
