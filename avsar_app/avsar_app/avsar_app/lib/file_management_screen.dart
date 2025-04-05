import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FileManagementScreen extends StatefulWidget {
  final String baseUrl;
  const FileManagementScreen({super.key, required this.baseUrl});

  @override
  _FileManagementScreenState createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  List<Map<String, dynamic>> files = [];
  bool isLoading = true;
  String currentPath = "";
  String? username;

  @override
  void initState() {
    super.initState();
    _loadUserAndFetch();
  }

  Future<void> _loadUserAndFetch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');
    fetchFiles();
  }

  Future<void> fetchFiles([String path = ""]) async {
    if (username == null) return;

    setState(() {
      isLoading = true;
      currentPath = path;
    });
    try {
      final uri = Uri.parse(
          "${widget.baseUrl}/files/browse?path=${Uri.encodeComponent(path)}&username=$username");
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        setState(() {
          files = List<Map<String, dynamic>>.from(
              jsonDecode(utf8.decode(response.bodyBytes)));
          isLoading = false;
        });
      } else {
        throw Exception("Dosyalar alınamadı");
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Dosya alınırken hata oluştu: $e")),
      );
    }
  }

  Future<void> downloadAndOpenFile(String relativePath) async {
    final url = Uri.parse(
        "${widget.baseUrl}/files/download/${Uri.encodeComponent(relativePath)}");

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

  void navigateIntoFolder(String folderName) {
    final newPath =
        currentPath.isEmpty ? folderName : "$currentPath/$folderName";
    fetchFiles(newPath);
  }

  bool get isInSubFolder => currentPath.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Dosya Yönetimi",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isInSubFolder)
                    Text("Bulunulan klasör: $currentPath",
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: files.isEmpty
                        ? const Center(
                            child: Text("Hiç dosya veya klasör yok."))
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
                ],
              ),
            ),
    );
  }
}
