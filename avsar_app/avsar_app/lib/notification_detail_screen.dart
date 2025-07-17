import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotificationDetailScreen extends StatelessWidget {
  final String sender;
  final String subject;
  final String content;
  final DateTime timestamp;

  const NotificationDetailScreen({
    super.key,
    required this.sender,
    required this.subject,
    required this.content,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, color: Colors.purple, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        sender,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                      DateFormat('dd MMMM yyyy / HH:mm', 'tr_TR')
                          .format(timestamp),
                      style:
                          const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (subject.isNotEmpty) ...[
                  const Text(
                    'Konu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject,
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
                  content,
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
