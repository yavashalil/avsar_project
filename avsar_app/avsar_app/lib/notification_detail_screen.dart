import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationDetailScreen extends StatelessWidget {
  final String sender;
  final String subject;
  final String content;
  final DateTime? timestamp; 

  const NotificationDetailScreen({
    super.key,
    required this.sender,
    required this.subject,
    required this.content,
    required this.timestamp,
  });

  String _sanitize(String input) {
    String safe = input.trim();
    if (safe.length > 500) {
      safe = safe.substring(0, 500) + "...";
    }
    return safe;
  }

  @override
  Widget build(BuildContext context) {
    final safeSender = _sanitize(sender.isNotEmpty ? sender : "Bilinmiyor");
    final safeSubject = _sanitize(subject);
    final safeContent = _sanitize(content.isNotEmpty ? content : "Mesaj yok");

    String dateString = "Tarih Yok";
    if (timestamp != null) {
      try {
        dateString = DateFormat('dd MMMM yyyy / HH:mm', 'tr_TR').format(timestamp!);
      } catch (e) {
        dateString = "Geçersiz Tarih";
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFDF0FA),
      appBar: AppBar(
        title: const Text(
          'Bildirim Detayı',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.purple,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ListView(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.purple, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        safeSender,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        color: Colors.purple, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      dateString,
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (safeSubject.isNotEmpty) ...[
                  const Text(
                    'Konu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    safeSubject,
                    style: const TextStyle(fontSize: 17),
                  ),
                  const SizedBox(height: 24),
                ],
                const Text(
                  'Mesaj',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 8),
                Text(
                  safeContent,
                  style: const TextStyle(fontSize: 17),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
