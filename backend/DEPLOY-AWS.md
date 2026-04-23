# Deploying the Vetviona License Backend on AWS

This document describes two production-ready deployment paths for `license_server.js` on AWS, plus the supporting pieces (TLS, DNS, secrets, observability). Both paths assume you've already followed the **AWS S3 Database Storage** section of [`README.md`](README.md) to provision the S3 bucket, KMS key, and IAM policy that hold the license database.

> **Why not Amplify?** Amplify is for hosting web apps + AWS-managed user/data/API stacks. The license backend is a single Node process talking to S3 — using bare AWS primitives (Fargate or Lambda) is simpler and cheaper.

---

## Architecture overview

```
              ┌──────────────────────┐
   HTTPS  →   │   Route 53 (DNS)     │   license.koshkikode.com
              └──────────┬───────────┘
                         ▼
              ┌──────────────────────┐
              │  ACM TLS certificate │   (AWS-issued, auto-renew)
              └──────────┬───────────┘
                         ▼
       ┌─────────────────┴────────────────┐
       │  Path A: ALB → ECS Fargate task  │
       │  Path B: API Gateway → Lambda    │
       └─────────────────┬────────────────┘
                         ▼
              ┌──────────────────────┐
              │  S3 (license-db.json)│  ← KMS-encrypted
              └──────────────────────┘

   Secrets:  Secrets Manager  ── LICENSE_KEY_SECRET, ADMIN_SECRET, SMTP_PASS
   Logs:     CloudWatch Logs
   Email:    Amazon SES (recommended) or external SMTP
```

---

## Pre-deploy: shared infrastructure

### 1. DNS — Route 53

Create a hosted zone for the apex domain (e.g. `koshkikode.com`) if you don't already have one. You'll add an A/AAAA alias record for `license.koshkikode.com` once Path A or Path B is live.

### 2. TLS — AWS Certificate Manager (ACM)

```bash
aws acm request-certificate \
  --domain-name license.koshkikode.com \
  --validation-method DNS \
  --region us-east-1
```

Add the `CNAME` records ACM gives you to Route 53 to validate.

> For Path B (API Gateway custom domain) the certificate must be in the **same region** as the API. For Path A (ALB) the cert is in the same region as the ALB.

### 3. Secrets — AWS Secrets Manager

Store the application secrets so they're never baked into the image / Lambda zip:

```bash
aws secretsmanager create-secret \
  --name vetviona/license/LICENSE_KEY_SECRET \
  --secret-string "$(openssl rand -hex 32)"

aws secretsmanager create-secret \
  --name vetviona/license/ADMIN_SECRET \
  --secret-string "$(openssl rand -hex 24)"

# Only needed if using SMTP outside SES, e.g. SendGrid:
aws secretsmanager create-secret \
  --name vetviona/license/SMTP_PASS \
  --secret-string "<smtp-password>"
```

### 4. Email — Amazon SES (recommended)

SES is the cheapest path on AWS and integrates with the same IAM model.

```bash
# Verify the From address (sandbox mode)
aws ses verify-email-identity --email-address noreply@koshkikode.com

# Move out of the SES sandbox via the console once production is ready.
```

Then set the backend env vars to use SES SMTP:

| Variable | Value |
|----------|-------|
| `SMTP_HOST` | `email-smtp.us-east-1.amazonaws.com` |
| `SMTP_PORT` | `587` |
| `SMTP_USER` | (from SES SMTP credentials) |
| `SMTP_PASS` | (from SES SMTP credentials) |
| `EMAIL_FROM` | `Vetviona <noreply@koshkikode.com>` |

---

## Path A — ECS Fargate (recommended for steady traffic)

Best when you expect more than a handful of requests per minute, want a long-running Node process, or want a single container image you can also run locally.

### A1. Containerize

Create `backend/Dockerfile` (not currently in the repo — add when adopting this path):

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --include=optional
COPY license_server.js ./
EXPOSE 8080
CMD ["node", "license_server.js"]
```

### A2. Push to ECR

```bash
aws ecr create-repository --repository-name vetviona/license

aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com

docker build -t vetviona/license backend/
docker tag vetviona/license:latest <account>.dkr.ecr.us-east-1.amazonaws.com/vetviona/license:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/vetviona/license:latest
```

### A3. ECS Fargate task

- **Cluster:** create a Fargate cluster (`vetviona-prod`).
- **Task definition:** 0.25 vCPU / 0.5 GB is plenty for the license server.
  - Container port: `8080`
  - Environment variables: `AWS_S3_BUCKET`, `AWS_S3_KEY`, `AWS_KMS_KEY_ID`, `AWS_REGION`, `MAX_DEVICES_PER_LICENSE`, `EMAIL_FROM`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`
  - Secrets (from Secrets Manager): `LICENSE_KEY_SECRET`, `ADMIN_SECRET`, `SMTP_PASS`
  - Log driver: `awslogs` → CloudWatch group `/ecs/vetviona-license`
- **Task IAM role** must allow:
  - `s3:GetObject`, `s3:PutObject` on the license-db key (per `README.md`)
  - `kms:GenerateDataKey`, `kms:Decrypt` on the KMS key
  - `secretsmanager:GetSecretValue` on the three secrets
  - `ses:SendEmail`, `ses:SendRawEmail` on the verified identity (only if using SES API; SMTP creds don't need this)
- **Service:** desired count `1` (or `2` across AZs for HA), behind an ALB.

### A4. ALB + Route 53

- Create an internet-facing ALB with an HTTPS listener using the ACM cert.
- Target group: IP type, port 8080, health check path `/health`.
- Add an A-record alias in Route 53 for `license.koshkikode.com` → the ALB.

### A5. Configure the Flutter app

```bash
flutter build <platform> --dart-define=LICENSE_BACKEND_URL=https://license.koshkikode.com
```

### Cost estimate (us-east-1, ballpark)

| Component | Monthly |
|-----------|---------|
| Fargate (1 task, 0.25 vCPU / 0.5 GB, 24×7) | ~$9 |
| ALB | ~$16 + traffic |
| S3 + KMS + CloudWatch | ~$1 |
| SES (first 62k emails free from EC2) | $0 |
| Route 53 hosted zone | $0.50 |
| **Total** | **~$26 / month** |

A $1k credit covers ~3 years at this size before traffic costs.

---

## Path B — Lambda + API Gateway (recommended for bursty / low traffic)

Best when traffic is sporadic (license verifications happen on app install / re-launch). Pay only per request. Slightly more setup because `shelf` needs an adapter.

### B1. Add a Lambda handler

Wrap the existing `shelf` handler with [`@vendia/serverless-express`](https://www.npmjs.com/package/@vendia/serverless-express) or rewrite the routes against `aws-lambda` event shapes. Save as `backend/lambda.js`. (Not in the repo — add when adopting this path.)

### B2. Package and deploy

```bash
cd backend
npm install --omit=dev --include=optional
zip -r ../license-lambda.zip . -x ".*"

aws lambda create-function \
  --function-name vetviona-license \
  --runtime nodejs20.x \
  --handler lambda.handler \
  --memory-size 512 \
  --timeout 15 \
  --role arn:aws:iam::<account>:role/vetviona-license-lambda \
  --zip-file fileb://../license-lambda.zip \
  --environment "Variables={AWS_S3_BUCKET=...,AWS_S3_KEY=vetviona/license-db.json,AWS_KMS_KEY_ID=alias/vetviona-license-db,EMAIL_FROM=...,SMTP_HOST=...,SMTP_PORT=587,SMTP_USER=...}"
```

Inject `LICENSE_KEY_SECRET`, `ADMIN_SECRET`, and `SMTP_PASS` via the Lambda Secrets Manager extension or by reading them at cold-start.

### B3. API Gateway

- Create an HTTP API (cheaper than REST API).
- Default stage `$default`.
- Attach the Lambda integration.
- Custom domain `license.koshkikode.com` → ACM cert → API mapping.
- Add the Route 53 A-alias to the API Gateway distribution.

### B4. IAM role for the Lambda

Same permissions as the Fargate task role in A3 (S3 + KMS + Secrets Manager + optional SES).

### Cost estimate (us-east-1)

| Component | Monthly |
|-----------|---------|
| Lambda (100k invocations, 512 MB, 200 ms each) | < $1 |
| API Gateway HTTP API (100k requests) | ~$0.10 |
| S3 + KMS + CloudWatch + Route 53 + SES | ~$2 |
| **Total** | **~$3 / month** |

Effectively free under your $1k credit until you cross ~10M requests/month.

---

## Observability

| Concern | Service |
|---------|---------|
| Application logs | CloudWatch Logs (`/ecs/vetviona-license` or `/aws/lambda/vetviona-license`) |
| Request metrics / latency | ALB CloudWatch metrics or API Gateway metrics |
| Health alarm | CloudWatch alarm on `/health` 5xx rate → SNS → email |
| Cost alarms | AWS Budgets alert at $50, $250, $500 of credit consumed |
| Audit | S3 access logs (already enabled in `README.md` step 1) + CloudTrail |

---

## Deployment checklist

- [ ] S3 bucket + KMS key created (per `README.md`)
- [ ] Secrets created in Secrets Manager
- [ ] ACM certificate issued and validated
- [ ] Route 53 hosted zone configured
- [ ] SES sender identity verified (or external SMTP credentials in place)
- [ ] **Choose Path A (Fargate) or Path B (Lambda)** and deploy
- [ ] Custom-domain DNS resolves and serves a valid cert
- [ ] `/health` returns `200` from the public URL
- [ ] CloudWatch log group is receiving entries
- [ ] AWS Budget alarm configured (don't burn the $1k credit silently)
- [ ] Flutter app rebuilt with `--dart-define=LICENSE_BACKEND_URL=https://license.koshkikode.com`

---

## Tear-down

If you ever migrate away, delete in this order to avoid orphaned billable resources:

1. Service / Lambda function
2. ALB / API Gateway
3. Target group
4. ECS task definition / ECR repository
5. CloudWatch log groups
6. Route 53 records (then hosted zone if no longer needed)
7. ACM certificate
8. Secrets Manager secrets (note: deletion is delayed by 7–30 days)
9. **S3 bucket + KMS key — only after exporting the license database**
