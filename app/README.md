# vetviona_app

Vetviona — a private, local-first genealogy app by KoshkiKode.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Platform Permission Setup

The following sections cover native permissions required for RootLoop™ sync
features.  These are needed when generating the Android and iOS platform
directories for the first time (`flutter create --platforms android,ios`).

### Android — `app/android/app/src/main/AndroidManifest.xml`

```xml
<!-- BLE scanning (peer discovery) -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />

<!-- NFC tap-to-pair -->
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="false" />

<!-- WiFi / local network sync -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />

<!-- Camera for QR code scanning -->
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS — `app/ios/Runner/Info.plist`

```xml
<!-- BLE scanning -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Vetviona uses Bluetooth to discover nearby devices for RootLoop™ sync.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Vetviona uses Bluetooth to broadcast its sync address to nearby devices.</string>

<!-- NFC tap-to-pair (read-only; writing to external tags is not supported on iOS) -->
<key>NFCReaderUsageDescription</key>
<string>Vetviona uses NFC to receive pairing info from another device.</string>
<key>com.apple.developer.nfc.readersession.formats</key>
<array>
    <string>NDEF</string>
</array>

<!-- Camera for QR code scanning -->
<key>NSCameraUsageDescription</key>
<string>Vetviona uses the camera to scan QR codes for RootLoop™ sync pairing.</string>

<!-- Local network access for WiFi sync -->
<key>NSLocalNetworkUsageDescription</key>
<string>Vetviona syncs family tree data with other devices on your local network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_vetviona._tcp</string>
</array>
```

> **Note:** The NFC entitlement (`com.apple.developer.nfc.readersession.formats`) must also
> be added in Xcode under **Signing & Capabilities → Near Field Communication Tag Reading**.
