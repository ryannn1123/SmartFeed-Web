import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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

  factory AIRecommendation.fromJson(
    Map<String, dynamic> json,
  ) {
    return AIRecommendation(
      morningTime:
          json['morning_time'].toString(),
      eveningTime:
          json['evening_time'].toString(),
      morningPortion:
          json['morning_portion'].toString().toLowerCase(),
      eveningPortion:
          json['evening_portion'].toString().toLowerCase(),
      reason:
          json['reason'].toString(),
      foodEfficiency:
          json['food_efficiency'].toString(),
      behaviorAdjustment:
          json['behavior_adjustment'].toString(),
    );
  }
}

class AIRecommendationService {
  static const String _url =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String _model =
      'openai/gpt-oss-20b';

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

IMPORTANT:

- Only use information from the supplied data.
- Do not invent feeding history.
- Do not diagnose medical conditions.
- Do not give veterinary or medical advice.
- Do not recommend calories or nutritional requirements.
- Do not make drastic schedule changes without evidence.
- Prefer the existing feeding pattern when it is consistent.
- Morning and evening times must use HH:MM 24-hour format.
- Portions must be small, medium, or full.
- Keep explanations short.
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

        // Prevent GPT-OSS from spending the response
        // on unnecessary reasoning instead of the JSON.
        'reasoning_effort': 'low',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Groq API error ${response.statusCode}: ${response.body}',
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

      final json =
          jsonDecode(content.toString());

      return AIRecommendation.fromJson(
        Map<String, dynamic>.from(json),
      );
    } catch (e) {
      throw Exception(
        'Failed to read AI recommendation:\n$e',
      );
    }
  }
}