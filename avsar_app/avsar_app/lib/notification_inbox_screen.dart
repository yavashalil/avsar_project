import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'notification_detail_screen.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() =>
      _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final storage = const FlutterSecureStorage();
  List<dynamic> messages = [];
  bool isLoading = true;
  late String baseUrl;

  @override
  void initState() {
    super.initState();
    baseUrl = dotenv.env['BASE_URL'] ?? '';
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() => isLoading = true);
    try {
      final username = await storage.read(key: 'username') ?? "";
      final token = await storage.read(key: 'token');

      if (username.isEmpty || token == null) {
        throw Exception("Kullanıcı bilgisi veya token bulunamadı.");
      }

      final response = await http.get(
        Uri.parse("$baseUrl/messages/inbox/$username"),
        headers: {
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          setState(() {
            messages = decoded;
            isLoading = false;
          });
        } else {
          throw Exception("Geçersiz API yanıtı.");
        }
      } else {
        throw Exception("Sunucu hatası: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  String formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return "Tarih Yok";
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('dd-MM-yyyy / HH:mm').format(dateTime);
    } catch (_) {
      return "Geçersiz Tarih";
    }
  }

  String sanitize(String? input) {
    if (input == null || input.trim().isEmpty) return "-";
    return input.trim().length > 200
        ? "${input.trim().substring(0, 200)}..."
        : input.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF0FA),
      appBar: AppBar(
        title: const Text(
          "Bildirimlerim",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : messages.isEmpty
              ? const Center(child: Text("Henüz bir bildirim yok."))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final content = sanitize(msg['content']);
                    final sender = sanitize(msg['sender_username']);
                    final subject = sanitize(msg['subject']);
                    final timestamp = formatTimestamp(msg['timestamp']);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 3,
                      child: ListTile(
                        title: Text(
                          content,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text("Gönderen: $sender\n$timestamp"),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationDetailScreen(
                                sender: sender,
                                subject: subject,
                                content: content,
                                timestamp: DateTime.tryParse(
                                      msg['timestamp'] ?? '',
                                    ) ??
                                    DateTime.now(),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
    );
  }
}
