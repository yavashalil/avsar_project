import 'package:avsar_app/admin_dashboard_screen.dart';
import 'package:avsar_app/file_management_screen.dart';
import 'package:avsar_app/login_screen.dart';
import 'package:avsar_app/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

String? globalUsername;

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty && globalUsername != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => FileManagementScreen(
              baseUrl: "http://10.0.2.2:5000",
              initialPath: payload,
              username: globalUsername!,
            ),
          ));
        });
      }
    },
  );

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

  final prefs = await SharedPreferences.getInstance();
  globalUsername = prefs.getString("username");

  await _initializeLocalNotifications();
  await initializeDateFormatting('tr_TR', null);
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
    _setupInitialLogic().then((_) {
      _setupFCMListeners();
    });
  }

  Future<void> _setupInitialLogic() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcm = FirebaseMessaging.instance;

      var settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print("Bildirim izni durumu: ${settings.authorizationStatus}");

      final token = await fcm.getToken();
      if (token != null) {
        debugPrint("FCM TOKEN: $token");
        await prefs.setString("fcmToken", token);
      }

      final username = prefs.getString('username') ?? "Bilinmiyor";
      final role = prefs.getString('role') ?? "User";

      globalUsername = username;

      if (username == "Bilinmiyor" || role == "User") {
        _initialRoute = "/login";
      } else if (role == "Admin") {
        _initialRoute = "/admin";
      } else {
        _initialRoute = "/dashboard";
      }

      setState(() {});
    } catch (e) {
      debugPrint("Hata oluştu: $e");
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
      _handleMessage(message);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        _handleMessage(message);
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    final relativePath = message.data['fileurl'];
    if (relativePath != null &&
        relativePath.isNotEmpty &&
        globalUsername != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => FileManagementScreen(
            baseUrl: "http://10.0.2.2:5000",
            initialPath: relativePath,
            username: globalUsername!,
          ),
        ));
      });
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final payload = message.data['fileurl'] ?? "";

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
      payload: payload,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: _initialRoute,
      routes: {
        "/login": (context) => const LoginScreen(),
        "/dashboard": (context) => const DashboardScreen(),
        "/admin": (context) => const AdminDashboardScreen(baseUrl: ''),
      },
    );
  }
}
