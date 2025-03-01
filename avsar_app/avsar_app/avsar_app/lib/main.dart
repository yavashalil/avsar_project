import 'package:avsar_app/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    _getInitialRoute();
  }

  Future<void> _getInitialRoute() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String username = prefs.getString('username') ?? "Bilinmiyor";
      String role = prefs.getString('role') ?? "User";

      if (username == "Bilinmiyor" || role == "User") {
        setState(() => _initialRoute = "/login");
      } else if (role == "Admin") {
        setState(() => _initialRoute = "/admin");
      } else {
        setState(() => _initialRoute = "/dashboard");
      }
    } catch (e) {
      print("Hata: $e");
      setState(() => _initialRoute = "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: _initialRoute,
      routes: {
        "/login": (context) => const LoginScreen(),
        "/dashboard": (context) => const DashboardScreen(),
        "/admin": (context) => const AdminDashboardScreen(
              baseUrl: '',
            ),
      },
    );
  }
}
