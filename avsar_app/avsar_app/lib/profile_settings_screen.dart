import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  String username = "Bilinmiyor";
  String unit = "Bilinmiyor";
  String selectedLanguage = "Türkçe";
  final String baseUrl = "http://192.168.2.100:5000";

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      setState(() {
        username = prefs.getString('username') ?? "Bilinmiyor";
        unit = prefs.getString('unit') ?? "Bilinmiyor";
        selectedLanguage = prefs.getString('language') ?? "Türkçe";
      });
    } catch (e) {
      print("Kullanıcı verileri yüklenirken hata oluştu: $e");
    }
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController _passwordController =
            TextEditingController();
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
                if (newPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Şifre boş olamaz!")),
                  );
                  return;
                }

                bool success = await changePassword(newPassword);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Şifre başarıyla güncellendi.")),
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Şifre güncelleme başarısız!")),
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
      final response = await http.put(
        Uri.parse('$baseUrl/change_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': newPassword}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            "Şifre değişikliği başarısız! HTTP Hata Kodu: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("API çağrısı başarısız: $e");
      return false;
    }
  }

  void _logout() async {
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
            Center(
              child: SizedBox(
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
            ),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.exit_to_app, color: Colors.white),
                label: const Text("Çıkış Yap"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
