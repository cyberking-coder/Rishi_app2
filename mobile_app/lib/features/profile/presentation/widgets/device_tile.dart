import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/registered_device.dart';

/// One row in the registered-device list. The dot is green only when this
/// row's fingerprint matches the current installation's fingerprint —
/// i.e. "this is the device you're holding right now", distinct from
/// [device.isActive] which reflects the server-side one-device-lock slot.
class DeviceTile extends StatelessWidget {
  final RegisteredDevice device;
  final bool isCurrentDevice;

  const DeviceTile({
    super.key,
    required this.device,
    required this.isCurrentDevice,
  });

  IconData get _platformIcon => switch (device.platform) {
        'android' => Icons.phone_android,
        'ios' => Icons.phone_iphone,
        _ => Icons.devices_other,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrentDevice ? Colors.greenAccent : Colors.white24,
            ),
          ),
          const SizedBox(width: 12),
          Icon(_platformIcon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.deviceName ?? 'Unknown device',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  isCurrentDevice
                      ? 'This device'
                      : device.isActive
                          ? 'Active'
                          : 'Last seen ${_relativeTime(device.lastSeenAt)}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!device.isActive)
            const Text('Inactive',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
