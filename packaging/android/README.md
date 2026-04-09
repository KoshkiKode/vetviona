# Android Signing — Vetviona

This document covers how to create and configure the Android signing keystore for release builds.

## Generating a keystore

Run this **once** on your local machine. Keep the resulting `.jks` file safe — losing it means you can never update your Play Store listing.

```bash
keytool -genkey -v \
  -keystore vetviona-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias vetviona \
  -dname "CN=KoshkiKode, OU=Vetviona, O=KoshkiKode, L=, S=, C=US"
```

Store the generated `vetviona-release-key.jks` somewhere **outside** the repository.

## Configuring the Flutter build

Create `app/android/key.properties` (this file is gitignored):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=vetviona
storeFile=/absolute/path/to/vetviona-release-key.jks
```

Then update `app/android/app/build.gradle` to reference it (Flutter scaffolds a template you can fill in).

## CI / GitHub Actions secrets

Add these repository secrets for the CI workflow to sign release builds:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 < vetviona-release-key.jks` |
| `ANDROID_STORE_PASSWORD` | Your keystore password |
| `ANDROID_KEY_PASSWORD` | Your key password |
| `ANDROID_KEY_ALIAS` | `vetviona` |

In the workflow, decode before building:

```yaml
- name: Decode keystore
  run: |
    echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 --decode > app/android/app/vetviona-release-key.jks
    cat > app/android/key.properties <<EOF
    storePassword=${{ secrets.ANDROID_STORE_PASSWORD }}
    keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
    keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
    storeFile=vetviona-release-key.jks
    EOF
```

## Bundle ID

The Android application ID is: **`com.koshkikode.vetviona`**

This must match:
- `app/android/app/build.gradle` → `applicationId`
- Play Console listing
- Any deep-link / intent-filter URIs
