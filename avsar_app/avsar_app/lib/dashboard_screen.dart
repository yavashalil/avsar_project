import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'profile_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String name = "Bilinmiyor";
  String unit = "Bilinmiyor";
  String role = "Bilinmiyor";
  String username = "";
  List<Map<String, dynamic>> files = [];
  bool isLoadingFiles = true;
  String currentPath = "";

  final String baseUrl = "http://10.0.2.2:5000";

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? "Bilinmiyor";
      unit = prefs.getString('unit') ?? "Bilinmiyor";
      role = prefs.getString('role') ?? "Bilinmiyor";
      username = prefs.getString('username') ?? "";
    });
    fetchFiles();
  }

  Future<void> fetchFiles([String path = ""]) async {
    setState(() {
      isLoadingFiles = true;
      currentPath = path;
    });
    try {
      final uri = Uri.parse(
          "$baseUrl/files/browse?path=${Uri.encodeComponent(path)}&username=$username");
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          files = List<Map<String, dynamic>>.from(
              jsonDecode(utf8.decode(response.bodyBytes)));
          isLoadingFiles = false;
        });
      } else {
        throw Exception("Dosyalar alınamadı");
      }
    } catch (e) {
      setState(() => isLoadingFiles = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya alınırken hata oluştu: $e")),
      );
    }
  }

  void navigateIntoFolderOrFile(String name, bool isFile) async {
    final newPath = currentPath.isEmpty ? name : "$currentPath/$name";
    if (isFile) {
      await openFile(newPath);
    } else {
      fetchFiles(newPath);
    }
  }

  Future<void> openFile(String relativePath) async {
    final url = Uri.parse(
        "$baseUrl/files/download/${Uri.encodeComponent(relativePath)}");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final dir = await getTemporaryDirectory();
        final fileName = relativePath.split('/').last;
        final filePath = "${dir.path}/$fileName";
        final file = File(filePath);

        await file.writeAsBytes(bytes);
        await OpenFile.open(filePath);
      } else {
        throw Exception("Dosya indirilemedi");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya açma hatası: $e")),
      );
    }
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  bool get isInSubFolder => currentPath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Avsar App",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (isInSubFolder) {
              final parent = currentPath.contains("/")
                  ? currentPath.substring(0, currentPath.lastIndexOf("/"))
                  : "";
              fetchFiles(parent);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text("Birim: $unit | Yetki: $role"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileSettingsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 10),
            Expanded(
              child: isLoadingFiles
                  ? const Center(child: CircularProgressIndicator())
                  : files.isEmpty
                      ? const Center(
                          child: Text("Hiç dosya veya klasör yok.",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            final file = files[index];
                            final name = file["name"] ?? "-";
                            final isFile = file["type"] == "file";
                            final date = file["date"] ?? "";

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Icon(
                                  isFile
                                      ? Icons.insert_drive_file_rounded
                                      : Icons.folder_rounded,
                                  color:
                                      isFile ? Colors.blueGrey : Colors.orange,
                                ),
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: isFile && date.isNotEmpty
                                    ? Text("📅 $date",
                                        style:
                                            const TextStyle(color: Colors.grey))
                                    : null,
                                onTap: () =>
                                    navigateIntoFolderOrFile(name, isFile),
                              ),
                            );
                          },
                        ),
            ),
            const Divider(),
            Center(
              child: ElevatedButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text("Çıkış Yap"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
