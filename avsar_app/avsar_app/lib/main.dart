import 'package:avsar_app/admin_dashboard_screen.dart';
import 'package:avsar_app/file_management_screen.dart';
import 'package:avsar_app/login_screen.dart';
import 'package:avsar_app/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final storage = const FlutterSecureStorage();

Future<void> _initializeLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  final initSettings = InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) async {
      final payload = response.payload;
      final username = await storage.read(key: "username");

      if (payload != null && payload.isNotEmpty && username != null) {
        if (payload.contains("..")) {
          debugPrint("Geçersiz dosya yolu engellendi: $payload");
          return;
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          navigatorKey.currentState?.push(MaterialPageRoute(
            builder: (_) => FileManagementScreen(
              baseUrl: dotenv.env['BASE_URL'] ?? '',
              initialPath: payload,
              username: username,
            ),
          ));
        });
      }
    },
  );

  const channel = AndroidNotificationChannel(
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
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();

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
      final fcm = FirebaseMessaging.instance;
      var settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint("Bildirim izni durumu: ${settings.authorizationStatus}");

      final token = await fcm.getToken();
      if (token != null) {
        await storage.write(key: "fcmToken", value: token);
      }

      final username = await storage.read(key: 'username') ?? "Bilinmiyor";
      final role = await storage.read(key: 'role') ?? "User";

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

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) {
        _handleMessage(message);
      }
    });
  }

  void _handleMessage(RemoteMessage message) async {
    final relativePath = message.data['fileurl'];
    final username = await storage.read(key: "username");

    if (relativePath != null &&
        relativePath.isNotEmpty &&
        username != null) {
      if (relativePath.contains("..")) {
        debugPrint("Geçersiz dosya yolu engellendi: $relativePath");
        return;
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => FileManagementScreen(
            baseUrl: dotenv.env['BASE_URL'] ?? '',
            initialPath: relativePath,
            username: username,
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
        "/admin": (context) =>
            AdminDashboardScreen(baseUrl: dotenv.env['BASE_URL'] ?? ''),
      },
    );
  }
}
