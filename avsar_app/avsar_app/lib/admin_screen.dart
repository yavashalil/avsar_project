import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_edit_screen.dart';
import 'user_add_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required String baseUrl});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> users = [];
  final String baseUrl = "http://192.168.2.100:5000";

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/'));
      if (response.statusCode == 200) {
        List<Map<String, dynamic>> fetchedUsers =
            List<Map<String, dynamic>>.from(
                jsonDecode(utf8.decode(response.bodyBytes)));

        if (mounted) {
          setState(() {
            users = fetchedUsers;
          });
        }
      } else {
        print("Kullanıcılar yüklenemedi! Hata kodu: ${response.statusCode}");
      }
    } catch (e) {
      print("Kullanıcıları çekerken hata oluştu: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Kullanıcı Ekle",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
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
                        builder: (context) => const UserAddScreen(
                              baseUrl: 'http://192.168.2.100:5000',
                            )),
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
