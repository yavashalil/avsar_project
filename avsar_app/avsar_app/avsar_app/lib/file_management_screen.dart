import 'package:flutter/material.dart';

class FileManagementScreen extends StatefulWidget {
  const FileManagementScreen({super.key});

  @override
  _FileManagementScreenState createState() => _FileManagementScreenState();
}

class _FileManagementScreenState extends State<FileManagementScreen> {
  // Örnek dosya listesi
  List<Map<String, String>> files = [
    {"name": "Rapor.pdf", "date": "02.02.2024"},
    {"name": "ToplantıNotları.docx", "date": "01.02.2024"},
  ];

  // Dosya Silme İşlemi
  void _deleteFile(int index) {
    setState(() {
      files.removeAt(index);
    });
  }

  // Dosya Yükleme İşlemi (Geçici olarak sadece listeye ekler)
  void _uploadFile() {
    setState(() {
      files.add({"name": "YeniDosya.txt", "date": "03.02.2024"});
    });
  }

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
          icon: const Icon(Icons.arrow_back,
              color: Colors.white), 
          onPressed: () {
            Navigator.pop(context); 
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dosya Listesi
            Expanded(
              child: ListView.builder(
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final fileName = files[index]["name"] ?? "Bilinmeyen Dosya";
                  final fileDate = files[index]["date"] ?? "Bilinmeyen Tarih";
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      title: Text(
                        fileName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "📅 $fileDate",
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                      trailing: Wrap(
                        spacing: -8, 
                        children: [
                          IconButton(
                            icon:
                                const Icon(Icons.download, color: Colors.blue),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text("$fileName indiriliyor...")),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteFile(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // [+ Yeni Dosya Yükle] Butonu
            Center(
              child: ElevatedButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(Icons.upload, color: Colors.white),
                label: const Text("Yeni Dosya Yükle"),
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
