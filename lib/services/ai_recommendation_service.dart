import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AIRecommendation {
  final String morningTime;
  final String eveningTime;
  final String morningPortion;
  final String eveningPortion;
  final String reason;
  final String foodEfficiency;
  final String behaviorAdjustment;

  AIRecommendation({
    required this.morningTime,
    required this.eveningTime,
    required this.morningPortion,
    required this.eveningPortion,
    required this.reason,
    required this.foodEfficiency,
    required this.behaviorAdjustment,
  });

  factory AIRecommendation.fromJson(Map<String, dynamic> json) {
    return AIRecommendation(
      morningTime: json['morning_time'].toString(),
      eveningTime: json['evening_time'].toString(),
      morningPortion: json['morning_portion'].toString().toLowerCase(),
      eveningPortion: json['evening_portion'].toString().toLowerCase(),
      reason: json['reason'].toString(),
      foodEfficiency: json['food_efficiency'].toString(),
      behaviorAdjustment: json['behavior_adjustment'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'morning_time': morningTime,
      'evening_time': eveningTime,
      'morning_portion': morningPortion,
      'evening_portion': eveningPortion,
      'reason': reason,
      'food_efficiency': foodEfficiency,
      'behavior_adjustment': behaviorAdjustment,
    };
  }
}

class AIRecommendationService {
  static const String _url =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String _model = 'openai/gpt-oss-20b';

  static final SupabaseClient _supabase =
      Supabase.instance.client;

  // ============================================================
  // LOAD SAVED RECOMMENDATION
  // ============================================================

  static Future<AIRecommendation?> getSavedRecommendation() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    final response = await _supabase
        .from('ai_recommendations')
        .select(
          '''
          id,
          user_id,
          morning_time,
          evening_time,
          morning_portion,
          evening_portion,
          reason,
          food_efficiency,
          behavior_adjustment,
          created_at
          ''',
        )
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return AIRecommendation.fromJson({
      'morning_time': response['morning_time'],
      'evening_time': response['evening_time'],
      'morning_portion': response['morning_portion'],
      'evening_portion': response['evening_portion'],
      'reason': response['reason'],
      'food_efficiency': response['food_efficiency'],
      'behavior_adjustment': response['behavior_adjustment'],
    });
  }

  // ============================================================
  // SAVE / REPLACE RECOMMENDATION
  // ============================================================

  static Future<void> saveRecommendation(
    AIRecommendation recommendation,
  ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    await _supabase.from('ai_recommendations').upsert(
      {
        'user_id': user.id,
        'morning_time': _normalizeTime(
          recommendation.morningTime,
        ),
        'evening_time': _normalizeTime(
          recommendation.eveningTime,
        ),
        'morning_portion': recommendation.morningPortion,
        'evening_portion': recommendation.eveningPortion,
        'reason': recommendation.reason,
        'food_efficiency': recommendation.foodEfficiency,
        'behavior_adjustment':
            recommendation.behaviorAdjustment,
      },
      onConflict: 'user_id',
    );
  }

  // ============================================================
  // GENERATE NEW AI RECOMMENDATION
  // ============================================================

  static Future<AIRecommendation> generateRecommendation({
    required List<Map<String, dynamic>> feedingLogs,
    required List<Map<String, dynamic>> schedules,
  }) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'GROQ_API_KEY is missing from .env',
      );
    }

    final prompt = '''
You are the AI recommendation engine for SmartFeed,
an IoT-based automatic household pet feeding system.

Analyze the supplied feeding history and current schedule.

FEEDING HISTORY:
${jsonEncode(feedingLogs)}

CURRENT SCHEDULE:
${jsonEncode(schedules)}

Analyze:

1. Recent feeding times.
2. Portion sizes.
3. Manual versus scheduled feeding.
4. Feeding patterns.
5. A practical morning feeding time.
6. A practical evening feeding time.
7. A suitable morning portion.
8. A suitable evening portion.
9. How food can be used efficiently.
10. An adjustment based on observed feeding behavior.

PORTION RULES:

Small = 45 degrees
Medium = 90 degrees
Full = 180 degrees

IMPORTANT RULES:

- Only use information from the supplied data.
- Do not invent feeding history.
- Do not diagnose medical conditions.
- Do not give veterinary or medical advice.
- Do not recommend calories or nutritional requirements.
- Do not make drastic schedule changes without evidence.
- Prefer the existing feeding pattern when it is consistent.
- Morning and evening times must use HH:MM 24-hour format.
- Portions must be exactly small, medium, or full.
- Keep explanations short and practical.
''';

    final response = await http.post(
      Uri.parse(_url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          },
        ],
        'response_format': {
          'type': 'json_schema',
          'json_schema': {
            'name': 'smartfeed_recommendation',
            'strict': true,
            'schema': {
              'type': 'object',
              'properties': {
                'morning_time': {
                  'type': 'string',
                },
                'evening_time': {
                  'type': 'string',
                },
                'morning_portion': {
                  'type': 'string',
                  'enum': [
                    'small',
                    'medium',
                    'full',
                  ],
                },
                'evening_portion': {
                  'type': 'string',
                  'enum': [
                    'small',
                    'medium',
                    'full',
                  ],
                },
                'reason': {
                  'type': 'string',
                },
                'food_efficiency': {
                  'type': 'string',
                },
                'behavior_adjustment': {
                  'type': 'string',
                },
              },
              'required': [
                'morning_time',
                'evening_time',
                'morning_portion',
                'evening_portion',
                'reason',
                'food_efficiency',
                'behavior_adjustment',
              ],
              'additionalProperties': false,
            },
          },
        },
        'temperature': 0.2,
        'max_tokens': 500,
        'reasoning_effort': 'low',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Groq API error ${response.statusCode}: '
        '${response.body}',
      );
    }

    try {
      final responseData =
          jsonDecode(response.body);

      final content =
          responseData['choices'][0]['message']['content'];

      if (content == null) {
        throw Exception(
          'Groq returned an empty recommendation.',
        );
      }

      final json = jsonDecode(content.toString());

      return AIRecommendation.fromJson(
        Map<String, dynamic>.from(json),
      );
    } catch (e) {
      throw Exception(
        'Failed to read AI recommendation:\n$e',
      );
    }
  }

  // ============================================================
  // TIME NORMALIZATION
  // ============================================================

  static String _normalizeTime(String time) {
    final parts = time.split(':');

    if (parts.length < 2) {
      throw Exception(
        'Invalid AI feeding time: $time',
      );
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw Exception(
        'Invalid AI feeding time: $time',
      );
    }

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:00';
  }
}