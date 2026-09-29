import 'package:supabase_flutter/supabase_flutter.dart';

class RecommendationDataService {
  static final SupabaseClient _supabase =
      Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getFeedingLogs() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    // Get feeding history from the feeder.
    // Existing feeding_logs have user_id = NULL,
    // so we do not filter by user_id here.
    final response = await _supabase
        .from('feeding_logs')
        .select(
          'id, user_id, fed_at, angle, portion_label, trigger_type',
        )
        .order('fed_at', ascending: false)
        .limit(50);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>> getSchedules() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final response = await _supabase
        .from('schedule')
        .select(
          'id, feed_time, angle, enabled, created_at, user_id, feed_date',
        )
        .eq('user_id', user.id)
        .eq('enabled', true)
        .order('feed_time', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }
}