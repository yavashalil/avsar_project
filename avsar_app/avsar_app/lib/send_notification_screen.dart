import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  String selectedUser = '';
  String message = '';
  String subject = '';
  List<String> users = [];

  final storage = const FlutterSecureStorage();
  late String baseUrl;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? '';
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    try {
      final token = await storage.read(key: 'token');
      if (token == null) throw Exception("Token bulunamadı");

      final response = await http.get(
        Uri.parse('$baseUrl/users/'),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          users = data.map<String>((user) => user['username'] as String).toList();
        });
      } else {
        _showSnack("Kullanıcılar alınamadı (Kod: ${response.statusCode})");
      }
    } catch (e) {
      _showSnack("Hata: $e");
    }
  }

  Future<void> sendNotification() async {
    try {
      final token = await storage.read(key: 'token');
      final sender = await storage.read(key: 'username') ?? 'admin';

      if (token == null) throw Exception("Token bulunamadı");

      final response = await http.post(
        Uri.parse('$baseUrl/messages/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode({
          'sender_username': sender,
          'receiver_username': selectedUser.trim(),
          'subject': subject.trim(),
          'content': message.trim(),
          'file_path': null,
          'reply_to': null
        }),
      );

      if (response.statusCode == 200) {
        _showSnack("Bildirim gönderildi!");
      } else {
        _showSnack("Hata: ${response.body}");
      }
    } catch (e) {
      _showSnack("Gönderim hatası: $e");
    }
  }

  void _showSnack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String? _validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) return 'Mesaj boş olamaz';
    if (value.length > 500) return 'Mesaj 500 karakteri geçemez';
    return null;
  }

  String? _validateSubject(String? value) {
    if (value != null && value.length > 100) return 'Konu 100 karakteri geçemez';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0FA),
      appBar: AppBar(
        title: const Text(
          'Bildirim Gönder',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.purple,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Kullanıcı Seç', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedUser.isNotEmpty ? selectedUser : null,
                  decoration: _inputDecoration(),
                  items: users.isNotEmpty
                      ? users.map((user) => DropdownMenuItem(value: user, child: Text(user))).toList()
                      : [const DropdownMenuItem(value: '', child: Text("Kullanıcı bulunamadı"))],
                  onChanged: (value) => setState(() => selectedUser = value ?? ''),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Lütfen bir kullanıcı seçin';
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Konu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  decoration: _inputDecoration(),
                  onChanged: (value) => subject = value,
                  validator: _validateSubject,
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mesaj', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: TextFormField(
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: _inputDecoration(hintText: 'Bildirim içeriğini yazın...'),
                    onChanged: (value) => message = value,
                    validator: _validateMessage,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Gönder', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 6,
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) sendNotification();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
