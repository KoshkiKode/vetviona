import 'package:uuid/uuid.dart';

class Device {
  String id;
  String sharedSecret;

  Device({required this.id, required this.sharedSecret});

  factory Device.create() {
    const uuid = Uuid();
    return Device(id: uuid.v4(), sharedSecret: uuid.v4());
  }

  Map<String, dynamic> toMap() => {'id': id, 'sharedSecret': sharedSecret};

  factory Device.fromMap(Map<String, dynamic> map) =>
      Device(id: map['id'] as String, sharedSecret: map['sharedSecret'] as String);
}
