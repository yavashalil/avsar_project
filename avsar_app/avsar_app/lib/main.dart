import 'package:avsar_app/admin_dashboard_screen.dart';
import 'package:avsar_app/file_management_screen.dart';
import 'package:avsar_app/login_screen.dart';
import 'package:avsar_app/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'default_channel',
    'Genel Bildirimler',
    description: 'Uygulama açıkken gelen bildirimler',
    importance: Importance.high,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initializeLocalNotifications();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _initialRoute = "/login";

  @override
  void initState() {
    super.initState();
    _setupInitialLogic();
    _setupFCMListeners();
  }

  Future<void> _setupInitialLogic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcm = FirebaseMessaging.instance;

      // 🔐 Bildirim izin durumu
      final settings = await fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      print("📢 Bildirim izni durumu: ${settings.authorizationStatus}");

      // 🔑 FCM token alma
      final token = await fcm.getToken();
      if (token != null) {
        print("🔑 FCM TOKEN: $token");
        await prefs.setString("fcmToken", token);
      }

      // Giriş kontrolü
      final username = prefs.getString('username') ?? "Bilinmiyor";
      final role = prefs.getString('role') ?? "User";

      if (username == "Bilinmiyor" || role == "User") {
        _initialRoute = "/login";
      } else if (role == "Admin") {
        _initialRoute = "/admin";
      } else {
        _initialRoute = "/dashboard";
      }

      setState(() {});
    } catch (e) {
      print("❌ Hata oluştu: $e");
      setState(() => _initialRoute = "/login");
    }
  }

  void _setupFCMListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final filepath = message.data['filepath'];
      final baseUrl = "http://192.168.2.7:5000";

      if (filepath != null && filepath.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FileManagementScreen(
              baseUrl: baseUrl,
              initialPath: filepath,
            ),
          ),
        );
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Genel Bildirimler',
      channelDescription: 'Uygulama açıkken gelen bildirimler',
      importance: Importance.max,
      priority: Priority.high,
    );

    const generalNotificationDetails =
        NotificationDetails(android: androidDetails);

    flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      generalNotificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: _initialRoute,
      routes: {
        "/login": (context) => const LoginScreen(),
        "/dashboard": (context) => const DashboardScreen(),
        "/admin": (context) => const AdminDashboardScreen(baseUrl: ''),
      },
    );
  }
}
