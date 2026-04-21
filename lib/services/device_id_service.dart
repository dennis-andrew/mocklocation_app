import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  DeviceIdService._();

  static const String storageKey = 'device_id';

  static String? _cachedDeviceId;
  static Future<String>? _inFlightDeviceId;

  static Future<String> getOrCreateDeviceId() {
    final String? cachedDeviceId = _cachedDeviceId;
    if (cachedDeviceId != null && cachedDeviceId.isNotEmpty) {
      return Future<String>.value(cachedDeviceId);
    }

    final Future<String>? pendingDeviceId = _inFlightDeviceId;
    if (pendingDeviceId != null) {
      return pendingDeviceId;
    }

    _inFlightDeviceId = _loadOrCreateDeviceId();
    return _inFlightDeviceId!;
  }

  static Future<String> _loadOrCreateDeviceId() async {
    try {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final String? existingDeviceId = preferences.getString(storageKey);

      if (existingDeviceId != null && existingDeviceId.isNotEmpty) {
        _cachedDeviceId = existingDeviceId;
        return existingDeviceId;
      }

      final String newDeviceId = const Uuid().v4();
      await preferences.setString(storageKey, newDeviceId);
      _cachedDeviceId = newDeviceId;
      return newDeviceId;
    } finally {
      _inFlightDeviceId = null;
    }
  }
}
