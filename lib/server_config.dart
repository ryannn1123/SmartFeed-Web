import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ServerConfig {
  static const int port = 5000;

  static String? _ip;

  static Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final row = await Supabase.instance.client
          .from('server_config')
          .select('flask_ip')
          .eq('id', 1)
          .single();

      final ip = row['flask_ip'] as String?;

      if (ip != null && ip.isNotEmpty) {
        _ip = ip;
        await prefs.setString('flask_ip', ip);
        return;
      }
    } catch (_) {
      // Supabase unreachable -> use the last known IP below.
    }

    _ip = prefs.getString('flask_ip');
  }

  static bool get isReady => _ip != null;

  static String get videoUrl => 'http://$_ip:$port/video';

  static String get detectionUrl => 'http://$_ip:$port/detection';
}