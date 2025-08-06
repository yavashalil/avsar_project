import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin_screen.dart';
import 'file_management_screen.dart';
import 'profile_settings_screen.dart';
import 'send_notification_screen.dart';
import 'notification_inbox_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final storage = const FlutterSecureStorage();
  String name = "Bilinmiyor";
  String unit = "Bilinmiyor";
  String role = "User";
  String username = "default_user";
  String baseUrl = "";

  @override
  void initState() {
    super.initState();
    _loadEnv();
    _loadUserData();
  }

  Future<void> _loadEnv() async {
    final urlFromEnv = dotenv.env['BASE_URL'];
    if (urlFromEnv == null || urlFromEnv.isEmpty) {
      debugPrint("⚠ BASE_URL bulunamadı! .env dosyanızı kontrol edin.");
    }
    setState(() => baseUrl = urlFromEnv);
  }

  Future<void> _loadUserData() async {
    // Secure Storage'dan verileri oku
    String? storedName = await storage.read(key: 'name');
    String? storedUnit = await storage.read(key: 'unit');
    String? storedRole = await storage.read(key: 'role');
    String? storedUsername = await storage.read(key: 'username');

    setState(() {
      name = storedName?.trim().isNotEmpty == true ? storedName!.trim() : "Bilinmiyor";
      unit = storedUnit?.trim().isNotEmpty == true ? storedUnit!.trim() : "Bilinmiyor";
      role = storedRole?.trim().isNotEmpty == true ? storedRole!.trim() : "User";
      username = storedUsername?.trim().isNotEmpty == true ? storedUsername!.trim() : "default_user";
    });
  }

  void _logout() async {
    final token = await storage.read(key: 'token');
    if (token != null && baseUrl.isNotEmpty) {
      try {
      } catch (_) {
        debugPrint("Backend logout bildirimi başarısız oldu.");
      }
    }

    await storage.deleteAll();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == "Admin"; 

    return Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF9C27B0),
                    Color(0xFF7B1FA2),
                    Color(0xFF6A1B9A),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Birim: $unit",
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  Text(
                    "Yetki: $role",
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (isAdmin)
              _buildDrawerItem(Icons.send, "Bildirim Gönder", () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => const SendNotificationScreen(),
                ));
              }),

            _buildDrawerItem(Icons.notifications, "Bildirimlerim", () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const NotificationInboxScreen(),
              ));
            }),
          ],
        ),
      ),
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Admin Yönetim Paneli",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: baseUrl.isEmpty
          ? const Center(child: Text("Sunucu adresi bulunamadı (.env kontrol edin)"))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.purple,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : "?",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Birim: $unit | Yetki: $role",
                          style: const TextStyle(fontSize: 14, color: Colors.grey)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileSettingsScreen(
                              usernameFromAdmin: username,
                              unitFromAdmin: unit,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 130),

                  if (isAdmin)
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => AdminScreen(baseUrl: baseUrl)),
                          );
                        },
                        child: const Text(
                          "Kullanıcı Yönetimi",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FileManagementScreen(
                              baseUrl: baseUrl,
                              username: username,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        "Dosya Yönetimi",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                      label: const Text(
                        "Çıkış Yap",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: Icon(icon, color: Colors.purple),
          title: Text(title),
          onTap: onTap,
        ),
      ),
    );
  }
}
