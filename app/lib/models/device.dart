import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:uuid/uuid.dart';

class Device {
  String id;
  String sharedSecret;

  Device({required this.id, required this.sharedSecret});

  Map<String, dynamic> toMap() {
    return {'id': id, 'sharedSecret': sharedSecret};
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(id: map['id'], sharedSecret: map['sharedSecret']);
  }
}
