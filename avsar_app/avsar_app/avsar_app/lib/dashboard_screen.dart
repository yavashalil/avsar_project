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
  String username = "";
  List<Map<String, dynamic>> files = [];
  bool isLoadingFiles = true;
  String currentPath = "";

  final String baseUrl = "http://192.168.2.100:5000";

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

  void navigateIntoFolder(String folderName) {
    final newPath =
        currentPath.isEmpty ? folderName : "$currentPath/$folderName";
    fetchFiles(newPath);
  }

  Future<void> downloadAndOpenFile(String relativePath) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dosya indirilemedi")),
        );
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
                subtitle: Text("Birim: $unit"),
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
            if (isInSubFolder)
              Text("Bulunulan klasör: $currentPath",
                  style: const TextStyle(fontSize: 14, color: Colors.grey)),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                title: Text(name),
                                subtitle:
                                    Text(isFile ? "📅 $date" : "📁 Klasör"),
                                trailing: isFile
                                    ? IconButton(
                                        icon: const Icon(Icons.download,
                                            color: Colors.blue),
                                        onPressed: () {
                                          final fullPath = currentPath.isEmpty
                                              ? name
                                              : "$currentPath/$name";
                                          downloadAndOpenFile(fullPath);
                                        },
                                      )
                                    : const Icon(Icons.folder,
                                        color: Colors.orange),
                                onTap: isFile
                                    ? null
                                    : () => navigateIntoFolder(name),
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
