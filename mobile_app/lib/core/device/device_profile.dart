class DeviceProfile {
  final String fingerprint;
  final String name;
  final String platform; // 'android' | 'ios'

  const DeviceProfile({
    required this.fingerprint,
    required this.name,
    required this.platform,
  });
}
