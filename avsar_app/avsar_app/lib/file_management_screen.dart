import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileManagementScreen extends StatefulWidget {
  final String baseUrl;
  final String? initialPath;
  final String username;

  const FileManagementScreen({
    super.key,
    required this.baseUrl,
    required this.username,
    this.initialPath,
  });

  @override
  State<FileManagementScreen> createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  List<Map<String, dynamic>> files = [];
  bool isLoading = true;
  String currentPath = "";
  late String username;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString("username") ?? widget.username;
      await _initialize();
    });
  }

  Future<void> _initialize() async {
    setState(() => isLoading = true);

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      print("📥 Bildirimden gelen dosya açılıyor: ${widget.initialPath!}");

      String sanitizedPath = Uri.decodeFull(widget.initialPath!);
      print("🧪 Path temizlenmeden: $sanitizedPath");

      // ORTAK/ prefix'ini temizle
      if (sanitizedPath.startsWith("ORTAK/")) {
        sanitizedPath = sanitizedPath.replaceFirst("ORTAK/", "");
        print("🧼 ORTAK/ kaldırıldı: $sanitizedPath");
      }

      try {
        await openFileFromServer(sanitizedPath);
      } catch (e) {
        print("❌ Dosya açma hatası: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("⚠️ Dosya açılamadı: $e")),
          );
        }
      }

      final folderPath = sanitizedPath.contains("/")
          ? sanitizedPath.substring(0, sanitizedPath.lastIndexOf("/"))
          : "";

      print("🧽 Klasör listelenecek path: $folderPath");
      await fetchFiles(folderPath);
    } else {
      await fetchFiles();
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchFiles([String path = ""]) async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? widget.username;

    print(
        "🌐 fetchFiles çağrısı: ${widget.baseUrl}/files/browse?path=${Uri.encodeFull(path)}&username=$username");

    setState(() {
      isLoading = true;
      currentPath = path;
    });

    try {
      final uri = Uri.parse(
          "${widget.baseUrl}/files/browse?path=${Uri.encodeFull(path)}&username=$username");

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> fetchedFiles =
            List<Map<String, dynamic>>.from(decoded);

        print("✅ fetchFiles tamamlandı. ${fetchedFiles.length} dosya bulundu");

        if (mounted) {
          setState(() {
            files = fetchedFiles;
            isLoading = false;
          });
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: Dosya alınamadı");
      }
    } catch (e) {
      print("❌ Dosya alma hatası: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Dosya alınırken hata: $e")),
        );
      }
    }
  }

  Future<void> openFileFromServer(String relativePath) async {
    try {
      if (relativePath.contains('%7E%24') || relativePath.contains('~\$')) {
        print("⛔ Geçici dosya tespit edildi, açma atlandı.");
        return;
      }

      final encodedPath = Uri.encodeFull(relativePath);
      final url = "${widget.baseUrl}/files/open/$encodedPath";
      print("🔗 Tam URL (encoded): $url");

      final response = await http.get(Uri.parse(url));
      print("📦 HTTP Durum: ${response.statusCode}");

      if (response.statusCode != 200) {
        throw Exception("Dosya indirilemedi.");
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = relativePath.split("/").last;
      final safeName = fileName.replaceAll("%", "_");
      final filePath = "${tempDir.path}/$safeName";

      print("💾 Dosya yazılıyor: $filePath");
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      print("📂 Dosya açılıyor...");
      final result = await OpenFile.open(filePath);
      print("✅ Açma sonucu: ${result.message}");

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("⚠️ Dosya açılamadı: ${result.message}")),
        );
      }
    } catch (e) {
      print("❌ Hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Dosya açılırken hata: $e")),
        );
      }
    }
  }

  void navigateIntoFolder(String folderName) {
    final newPath =
        currentPath.isEmpty ? folderName : "$currentPath/$folderName";
    fetchFiles(newPath);
  }

  bool get isInSubFolder => currentPath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    print(
        "🧱 build() çalıştı | isLoading: $isLoading | Dosya sayısı: ${files.length}");

    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Dosya Yönetimi", style: TextStyle(color: Colors.white)),
        centerTitle: true,
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: files.isEmpty
                  ? const Center(child: Text("Hiç dosya veya klasör yok."))
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
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: Icon(
                              isFile
                                  ? Icons.insert_drive_file
                                  : Icons.folder_rounded,
                              color: isFile ? Colors.blueGrey : Colors.orange,
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis)),
                            subtitle: isFile && date.isNotEmpty
                                ? Text("📅 $date",
                                    style: const TextStyle(color: Colors.grey))
                                : null,
                            onTap: () {
                              final fullPath = currentPath.isEmpty
                                  ? name
                                  : "$currentPath/$name";
                              if (isFile) {
                                openFileFromServer(fullPath);
                              } else {
                                navigateIntoFolder(name);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
