import 'package:uuid/uuid.dart';

/// The sync tier of a paired device, mirroring the [AppTier] values used at
/// build time.  Stored as a plain string so it survives database serialisation
/// without extra enums.
class Device {
  String id;
  String sharedSecret;

  /// The pricing tier the paired device is running.
  /// One of `'mobileFree'`, `'mobilePaid'`, or `'desktopPro'`.
  String tier;

  Device({required this.id, required this.sharedSecret, this.tier = 'mobileFree'});

  factory Device.create({String tier = 'mobileFree'}) {
    const uuid = Uuid();
    return Device(id: uuid.v4(), sharedSecret: uuid.v4(), tier: tier);
  }

  Map<String, dynamic> toMap() =>
      {'id': id, 'sharedSecret': sharedSecret, 'tier': tier};

  factory Device.fromMap(Map<String, dynamic> map) => Device(
        id: map['id'] as String,
        sharedSecret: map['sharedSecret'] as String,
        tier: (map['tier'] as String?) ?? 'mobileFree',
      );
}
