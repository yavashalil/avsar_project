import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'user_edit_screen.dart';
import 'user_add_screen.dart';

class AdminScreen extends StatefulWidget {
  final String role;
  const AdminScreen({super.key, required this.role});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> users = [];
  late String baseUrl;

  @override
  void initState() {
    super.initState();

    baseUrl = dotenv.env['BASE_URL'] ?? '';

    if (baseUrl.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sunucu adresi bulunamadı. Lütfen yapılandırmayı kontrol edin.")),
        );
        Navigator.pop(context);
      });
      return;
    }

    if (widget.role != "Admin") {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bu sayfaya erişim izniniz yok.")),
        );
      });
    } else {
      fetchUsers();
    }
  }

  Future<void> fetchUsers() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) {
        _handleSessionExpired();
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/'),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedUsers =
            List<Map<String, dynamic>>.from(
          jsonDecode(utf8.decode(response.bodyBytes)),
        );

        if (mounted) {
          setState(() => users = fetchedUsers);
        }
      } else if (response.statusCode == 401) {
        _handleSessionExpired();
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Yetkisiz erişim.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcılar yüklenemedi! (${response.statusCode})")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcıları çekerken hata: $e")),
        );
      }
    }
  }

  void _handleSessionExpired() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Oturum süresi doldu, lütfen tekrar giriş yapın.")),
    );
    storage.deleteAll();
    Navigator.pushReplacementNamed(context, "/login");
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != "Admin") {
      return const SizedBox();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Kullanıcı Yönetimi",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            title: Text(user["name"] ?? "Bilinmeyen Kullanıcı"),
                            subtitle: Text(
                              "Yetki: ${user["role"] ?? "Bilinmiyor"} | Birim: ${user["unit"] ?? "Bilinmiyor"}",
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserEditScreen(
                                    user: user,
                                    baseUrl: baseUrl,
                                  ),
                                ),
                              ).then((_) => fetchUsers());
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            if (widget.role == "Admin")
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Kullanıcı Ekle",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserAddScreen(
                          baseUrl: baseUrl,
                        ),
                      ),
                    ).then((_) => fetchUsers());
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
