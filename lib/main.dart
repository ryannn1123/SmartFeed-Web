import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'pages/splash_page.dart';
import 'pages/reset_password_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /////
  // Listen for Supabase password recovery
Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  final event = data.event;

  if (event == AuthChangeEvent.passwordRecovery) {
    print('=================================');
    print('PASSWORD RECOVERY EVENT RECEIVED');
    print('=================================');

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const ResetPasswordPage(),
      ),
    );
  }
});

  // Request notification permission
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

  // Get the FCM token
  final fcmToken = await FirebaseMessaging.instance.getToken();

  FirebaseMessaging.onMessage.listen(
  (RemoteMessage message) async {
    print('=================================');
    print('FCM MESSAGE RECEIVED');

    final title =
        message.notification?.title ?? '🐾 Pet Detected!';

    final body =
        message.notification?.body ??
            'A pet has been detected by SmartFeed.';

    print('Title: $title');
    print('Body: $body');

    print('SHOWING LOCAL NOTIFICATION...');

    try {
      await flutterLocalNotificationsPlugin.show(
  id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
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
  ),
);
      print('LOCAL NOTIFICATION DISPLAYED SUCCESSFULLY!');
    } catch (e) {
      print('LOCAL NOTIFICATION ERROR:');
      print(e);
    }

    print('=================================');
  },
);

  runApp(const SmartFeedApp());
}

final supabase = Supabase.instance.client;

class SmartFeedApp extends StatelessWidget {
  const SmartFeedApp({super.key});
////
  GlobalKey<NavigatorState>? get navigatorKey => null;

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
