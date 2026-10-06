import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'pages/splash_page.dart';
import 'pages/reset_password_page.dart';
import 'pages/servo_page.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();


final supabase = Supabase.instance.client;

Future<void> saveFcmToken() async {
  try {
    final user = supabase.auth.currentUser;

    if (user == null) {
      print('No logged-in user. FCM token will be saved later.');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();

    if (token == null || token.isEmpty) {
      print('FCM token is empty.');
      return;
    }

    await supabase.from('fcm_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );

    print('=================================');
    print('FCM TOKEN SAVED');
    print(token);
    print('=================================');
  } catch (e) {
    print('ERROR SAVING FCM TOKEN: $e');
  }
}


Future<void> handleNotificationData(
    Map<String, dynamic> data) async {
  print('=================================');
  print('NOTIFICATION DATA');
  print(data);

  final screen = data['screen'];
  final action = data['action'];

  if (screen == 'servo' || action == 'open_servo') {
    print('Opening ServoPage...');

    final navigator = navigatorKey.currentState;

    if (navigator != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const ServoPage(),
        ),
      );
    } else {
      print('Navigator is not ready.');
    }
  }
}

void handleLocalNotificationTap(
    NotificationResponse response) {
  print('=================================');
  print('LOCAL NOTIFICATION TAPPED');

  final payload = response.payload;

  print('Payload: $payload');

  if (payload == null || payload.isEmpty) {
    return;
  }

  try {
    final Map<String, dynamic> data =
        jsonDecode(payload);

    handleNotificationData(data);
  } catch (e) {
    print('Error decoding notification payload:');
    print(e);
  }
}

//



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ============================================================
  // LOCAL NOTIFICATIONS INITIALIZATION
  // ============================================================

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
    macOS: iosSettings,
  );

 await flutterLocalNotificationsPlugin.initialize(
  settings: initializationSettings,
  onDidReceiveNotificationResponse:
      handleLocalNotificationTap,
);

  // ============================================================
  // ANDROID NOTIFICATION PERMISSION
  // ============================================================

  final androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }

  // ============================================================
  // SUPABASE PASSWORD RECOVERY
  // ============================================================

  Supabase.instance.client.auth.onAuthStateChange.listen(
    (data) {
      final event = data.event;

      print('SUPABASE AUTH EVENT: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        print('=================================');
        print('PASSWORD RECOVERY EVENT RECEIVED');
        print('=================================');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = navigatorKey.currentState;

          if (navigator != null) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) => const ResetPasswordPage(),
              ),
            );
          } else {
            print('Navigator is not ready yet.');
          }
        });
      }
    },
  );

  // ============================================================
  // FIREBASE NOTIFICATION PERMISSION
  // ============================================================

  final notificationSettings =
      await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('=================================');
  print('NOTIFICATION AUTHORIZATION:');
  print(notificationSettings.authorizationStatus);
  print('=================================');

  // ============================================================
  // FCM TOKEN
  // ============================================================

  final fcmToken =
      await FirebaseMessaging.instance.getToken();

  print('=================================');
  print('FCM TOKEN:');
  print(fcmToken);
  print('=================================');

  // ============================================================
  // FCM TOKEN REFRESH
  // ============================================================

 FirebaseMessaging.instance.onTokenRefresh.listen(
  (newToken) async {
    print('=================================');
    print('FCM TOKEN REFRESHED:');
    print(newToken);
    print('=================================');

    await saveFcmToken();
  },
);

  // ============================================================
  // FOREGROUND FCM MESSAGE
  // ============================================================

  FirebaseMessaging.onMessage.listen(
    (RemoteMessage message) async {
      print('=================================');
      print('FCM MESSAGE RECEIVED');

      final title =
          message.notification?.title ??
              '🐾 Pet Detected!';

      final body =
          message.notification?.body ??
              'A pet has been detected by SmartFeed.';

      print('Title: $title');
      print('Body: $body');

      final data = message.data;

      print('Data: $data');

      final payload = jsonEncode({
        'screen': data['screen'] ?? 'servo',
        'pet_name': data['pet_name'] ?? '',
        'action': data['action'] ?? 'open_servo',
      });

      print('Showing local notification...');

      try {
        await flutterLocalNotificationsPlugin.show(
  id: DateTime.now()
      .millisecondsSinceEpoch
      .remainder(2147483647),
  title: title,
  body: body,
  notificationDetails: const NotificationDetails(
    android: AndroidNotificationDetails(
      'smartfeed_pet_detection',
      'Pet Detection',
      channelDescription:
          'Notifications when SmartFeed detects a pet.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
    macOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  ),
  payload: payload,
);

        print(
          'LOCAL NOTIFICATION DISPLAYED SUCCESSFULLY!',
        );
      } catch (e) {
        print('LOCAL NOTIFICATION ERROR:');
        print(e);
      }

      print('=================================');
    },
  );

  // ============================================================
  // BACKGROUND NOTIFICATION TAP
  // ============================================================

  FirebaseMessaging.onMessageOpenedApp.listen(
    (RemoteMessage message) {
      print('=================================');
      print('BACKGROUND NOTIFICATION TAPPED');

      handleNotificationData(message.data);
    },
  );

  // ============================================================
  // TERMINATED APP NOTIFICATION TAP
  // ============================================================

  final RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  runApp(const SmartFeedApp());

  if (initialMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        print('=================================');
        print('APP OPENED FROM NOTIFICATION');

        handleNotificationData(
          initialMessage.data,
        );
      },
    );
  }
}

// ============================================================
// SMARTFEED APP
// ============================================================

class SmartFeedApp extends StatelessWidget {
  const SmartFeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartFeed',
      debugShowCheckedModeBanner: false,

      navigatorKey: navigatorKey,

      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),

      home: const SplashPage(),
    );
  }
}