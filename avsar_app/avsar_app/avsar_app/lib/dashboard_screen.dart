import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'profile_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String username = "Bilinmiyor";
  String unit = "Bilinmiyor";
  List<Map<String, dynamic>> files = []; // API'den gelen dosyalar
  bool isLoadingFiles = true; // Yükleme durumunu takip et

  final String baseUrl = "http://192.168.2.100:5000";

  @override
  void initState() {
    super.initState();
    loadUserData();
    fetchFiles();
  }

  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      username = prefs.getString('username') ?? "Bilinmiyor";
      unit = prefs.getString('unit') ??
          "Bilinmiyor"; // Artık kaydedildiğinden emin ol
    });
  }

  // API'den dosya listesini çek
  Future<void> fetchFiles() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/files/'));
      if (response.statusCode == 200) {
        setState(() {
          files = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          isLoadingFiles = false; // Yükleme tamamlandı
        });
      } else {
        print("Dosyalar yüklenemedi! Hata kodu: ${response.statusCode}");
        setState(() {
          isLoadingFiles = false;
        });
      }
    } catch (e) {
      print("Dosyaları çekerken hata oluştu: $e");
      setState(() {
        isLoadingFiles = false;
      });
    }
  }

  // Dosya açma işlemi
  void openFile(String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("📂 $fileName açılıyor...")),
    );
  }

  void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Avsar App",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kullanıcı Bilgileri
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Text(
                    username.isNotEmpty ? username[0] : "?",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(username,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text("Birim: $unit"),
                onTap: () {
                  // Profil ayarlarına yönlendirme
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProfileSettingsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 📂 DOSYA LİSTESİ
            const Text(
              "📂 Dosyalar",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: isLoadingFiles
                  ? const Center(
                      child:
                          CircularProgressIndicator()) // Yükleniyor animasyonu
                  : files.isEmpty
                      ? const Center(
                          child: Text("📁 Henüz yüklenmiş dosya yok.",
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: files.length,
                          itemBuilder: (context, index) {
                            final fileName =
                                files[index]["name"] ?? "Bilinmeyen Dosya";
                            return Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.insert_drive_file,
                                    color: Colors.orange),
                                title: Text(fileName,
                                    style: const TextStyle(fontSize: 16)),
                                onTap: () => openFile(fileName),
                              ),
                            );
                          },
                        ),
            ),

            const Divider(),

            // 🛠️ ÇIKIŞ
            Center(
              child: ElevatedButton.icon(
                onPressed: logout,
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text("Çıkış Yap"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
