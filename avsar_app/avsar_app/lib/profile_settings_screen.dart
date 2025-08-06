import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ProfileSettingsScreen extends StatefulWidget {
  final String? usernameFromAdmin;
  final String? unitFromAdmin;

  const ProfileSettingsScreen({super.key, this.usernameFromAdmin, this.unitFromAdmin});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final storage = const FlutterSecureStorage();
  String username = "Bilinmiyor";
  String unit = "Bilinmiyor";
  late String baseUrl;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? '';
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      if (widget.usernameFromAdmin != null && widget.unitFromAdmin != null) {
        setState(() {
          username = widget.usernameFromAdmin!;
          unit = widget.unitFromAdmin!;
        });
      } else {
        final storedUsername = await storage.read(key: 'username');
        final storedUnit = await storage.read(key: 'unit');
        setState(() {
          username = storedUsername ?? "Bilinmiyor";
          unit = storedUnit ?? "Bilinmiyor";
        });
      }
    } catch (e) {
      debugPrint("Kullanıcı verileri yüklenirken hata: $e");
    }
  }

  void _changePassword() {
    final TextEditingController _passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Şifre Değiştir"),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: "Yeni Şifre"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () async {
                String newPassword = _passwordController.text.trim();
                
                if (newPassword.isEmpty || newPassword.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Şifre en az 8 karakter olmalı!")),
                  );
                  return;
                }

                bool success = await changePassword(newPassword);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Şifre başarıyla güncellendi.")),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Şifre güncelleme başarısız!")),
                  );
                }
              },
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  Future<bool> changePassword(String newPassword) async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Token bulunamadı!");

      final response = await http.put(
        Uri.parse('$baseUrl/change_password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'username': username, 'password': newPassword}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("API çağrısı başarısız: $e");
      return false;
    }
  }

  void _logout() async {
    await storage.deleteAll();
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
          "Profil ve Ayarlar",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Kullanıcı Adı: $username",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Birim: $unit",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.lock, color: Colors.white),
                label: const Text("Şifre Değiştir"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              label: const Text("Çıkış Yap"),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
