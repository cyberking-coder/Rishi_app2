class RegisteredDevice {
  final String id;
  final String deviceFingerprint;
  final String? deviceName;
  final String platform;
  final bool isActive;
  final DateTime lastSeenAt;
  final DateTime boundAt;

  const RegisteredDevice({
    required this.id,
    required this.deviceFingerprint,
    required this.platform,
    required this.isActive,
    required this.lastSeenAt,
    required this.boundAt,
    this.deviceName,
  });

  factory RegisteredDevice.fromMap(Map<String, dynamic> map) => RegisteredDevice(
        id: map['id'] as String,
        deviceFingerprint: map['device_fingerprint'] as String,
        deviceName: map['device_name'] as String?,
        platform: map['platform'] as String,
        isActive: map['is_active'] as bool,
        lastSeenAt: DateTime.parse(map['last_seen_at'] as String),
        boundAt: DateTime.parse(map['bound_at'] as String),
      );
}
