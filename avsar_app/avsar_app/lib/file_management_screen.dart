import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class FileManagementScreen extends StatefulWidget {
  final String? initialPath;
  final String username;

  const FileManagementScreen({
    super.key,
    required this.username,
    this.initialPath,
  });

  @override
  State<FileManagementScreen> createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  final storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> files = [];
  bool isLoading = true;
  String currentPath = "";
  late String baseUrl;
  late String username;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? '';
    username = widget.username;
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => isLoading = true);

    if (widget.initialPath != null && widget.initialPath!.isNotEmpty) {
      String sanitizedPath = Uri.decodeFull(widget.initialPath!);

      if (sanitizedPath.startsWith("ORTAK/")) {
        sanitizedPath = sanitizedPath.replaceFirst("ORTAK/", "");
      }

      if (sanitizedPath.contains("..")) {
        _showSnack("Geçersiz dosya yolu!");
        setState(() => isLoading = false);
        return;
      }

      try {
        await openFileFromServer(sanitizedPath);
      } catch (e) {
        _showSnack("Dosya açılamadı: $e");
      }

      final folderPath = sanitizedPath.contains("/")
          ? sanitizedPath.substring(0, sanitizedPath.lastIndexOf("/"))
          : "";
      await fetchFiles(folderPath);
    } else {
      await fetchFiles();
    }

    setState(() => isLoading = false);
  }

  Future<void> fetchFiles([String path = ""]) async {
    setState(() {
      isLoading = true;
      currentPath = path;
    });

    try {
      final token = await storage.read(key: 'token');
      final uri = Uri.parse(
          "$baseUrl/files/browse?path=${Uri.encodeFull(path)}&username=$username");

      final response = await http.get(uri, headers: {
        "Authorization": "Bearer $token",
      });

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> fetchedFiles =
            List<Map<String, dynamic>>.from(decoded);

        setState(() {
          files = fetchedFiles;
          isLoading = false;
        });
      } else {
        throw Exception("HTTP ${response.statusCode}: Dosya alınamadı");
      }
    } catch (e) {
      _showSnack("Dosya alınırken hata: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> openFileFromServer(String relativePath) async {
    try {
      if (relativePath.contains('%7E%24') || relativePath.contains('~\$')) {
        return;
      }

      final token = await storage.read(key: 'token');
      final encodedPath = Uri.encodeFull(relativePath);
      final url = "$baseUrl/files/open/$encodedPath";

      final response = await http.get(Uri.parse(url), headers: {
        "Authorization": "Bearer $token",
      });

      if (response.statusCode != 200) {
        throw Exception("Dosya indirilemedi (${response.statusCode})");
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = relativePath.split("/").last;
      final safeName = fileName.replaceAll("%", "_");
      final filePath = "${tempDir.path}/$safeName";

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        _showSnack("Dosya açılamadı: ${result.message}");
      }
    } catch (e) {
      _showSnack("Dosya açılırken hata: $e");
    }
  }

  void navigateIntoFolder(String folderName) {
    if (folderName.contains("..")) {
      _showSnack("Geçersiz klasör yolu!");
      return;
    }
    final newPath =
        currentPath.isEmpty ? folderName : "$currentPath/$folderName";
    fetchFiles(newPath);
  }

  void _showSnack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  bool get isInSubFolder => currentPath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
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
                            title: Text(
                              name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            subtitle: isFile && date.isNotEmpty
                                ? Text("$date",
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
