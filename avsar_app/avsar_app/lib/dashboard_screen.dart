import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'profile_settings_screen.dart';
import 'notification_inbox_screen.dart';
import 'send_notification_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final storage = const FlutterSecureStorage();
  String name = "Bilinmiyor";
  String unit = "Bilinmiyor";
  String role = "Bilinmiyor";
  String username = "";
  List<Map<String, dynamic>> files = [];
  bool isLoadingFiles = true;
  String currentPath = "";

  late String baseUrl;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? '';
    loadUserData();
  }

  Future<void> loadUserData() async {
    name = await storage.read(key: 'name') ?? "Bilinmiyor";
    unit = await storage.read(key: 'unit') ?? "Bilinmiyor";
    role = await storage.read(key: 'role') ?? "Bilinmiyor";
    username = await storage.read(key: 'username') ?? "";

    if (mounted) setState(() {});
    fetchFiles();
  }

  Future<void> fetchFiles([String path = ""]) async {
    setState(() {
      isLoadingFiles = true;
      currentPath = path;
    });

    try {
      final token = await storage.read(key: 'token');
      final uri = Uri.parse(
          "$baseUrl/files/browse?path=${Uri.encodeComponent(path)}&username=$username");

      final response = await http.get(uri, headers: {
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        setState(() {
          files = List<Map<String, dynamic>>.from(
              jsonDecode(utf8.decode(response.bodyBytes)));
          isLoadingFiles = false;
        });
      } else {
        throw Exception("Dosyalar alınamadı (${response.statusCode})");
      }
    } catch (e) {
      setState(() => isLoadingFiles = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya alınırken hata: $e")),
      );
    }
  }

  void navigateIntoFolderOrFile(String name, bool isFile) async {
    if (name.contains("..")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Geçersiz dosya yolu")),
      );
      return;
    }

    final newPath = currentPath.isEmpty ? name : "$currentPath/$name";
    if (isFile) {
      await openFile(newPath);
    } else {
      fetchFiles(newPath);
    }
  }

  Future<void> openFile(String relativePath) async {
    try {
      final token = await storage.read(key: 'token');
      final url = Uri.parse("$baseUrl/files/open/${Uri.encodeComponent(relativePath)}");

      final response = await http.get(url, headers: {
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final fileName = relativePath.split('/').last;
        final filePath = "${dir.path}/$fileName";

        final file = File(filePath);
        await file.writeAsBytes(bytes);
        await OpenFile.open(filePath);
      } else {
        throw Exception("Dosya indirilemedi (${response.statusCode})");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya açma hatası: $e")),
      );
    }
  }

  void logout() async {
    await storage.deleteAll();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  bool get isInSubFolder => currentPath.isNotEmpty;

  void navigateBack() {
    if (isInSubFolder) {
      final parent = currentPath.contains("/")
          ? currentPath.substring(0, currentPath.lastIndexOf("/"))
          : "";
      fetchFiles(parent);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text("Birim: $unit",
                      style: const TextStyle(color: Colors.white70)),
                  Text("Yetki: $role",
                      style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Admin role kontrolü
            if (role == "Admin")
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.send, color: Colors.purple),
                    title: const Text("Bildirim Gönder"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const SendNotificationScreen()),
                      );
                    },
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Card(
                child: ListTile(
                  leading:
                      const Icon(Icons.notifications, color: Colors.purple),
                  title: const Text("Bildirimlerim"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              const NotificationInboxScreen()),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("Avsar App"),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isInSubFolder)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: navigateBack,
            )
        ],
      ),
      body: isLoadingFiles
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? const Center(child: Text("Hiç dosya yok"))
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final name = file["name"] ?? "-";
                    final isFile = file["type"] == "file";
                    final date = file["date"] ?? "";

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isFile
                              ? Icons.insert_drive_file
                              : Icons.folder,
                          color: isFile ? Colors.blueGrey : Colors.orange,
                        ),
                        title: Text(name),
                        subtitle:
                            isFile && date.isNotEmpty ? Text("$date") : null,
                        onTap: () =>
                            navigateIntoFolderOrFile(name, isFile),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton.icon(
          onPressed: logout,
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          label: const Text("Çıkış Yap"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ),
    );
  }
}
