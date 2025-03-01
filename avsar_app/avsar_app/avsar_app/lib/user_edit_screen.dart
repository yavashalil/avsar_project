import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String baseUrl;

  const UserEditScreen({super.key, required this.user, required this.baseUrl});

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late String _role;
  late String _unit;

  final List<String> _units = [
    'Muhasebe',
    'Pazarlama',
    'IK',
    'Satin Alma',
    'Finans',
    'Bilgi Islem',
    'Satis'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _usernameController = TextEditingController(text: widget.user['username']);
    _passwordController = TextEditingController();
    _role = widget.user['role'] ?? 'User';
    _unit = _units.contains(widget.user['unit'])
        ? widget.user['unit']
        : _units.first;
  }

  Future<void> _updateUser() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await http.put(
          Uri.parse('${widget.baseUrl}/users/${widget.user['username']}'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'username': _usernameController.text,
            'name': _nameController.text,
            'unit': _unit,
            'role': _role,
            'password': _passwordController.text.isNotEmpty
                ? _passwordController.text
                : null,
          }),
        );

        if (response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("Kullanıcı güncellenemedi! Hata: ${response.body}")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Beklenmeyen bir hata oluştu!")),
        );
      }
    }
  }

  Future<void> _confirmDeleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullanıcıyı Sil'),
          content: const Text(
              'Kullanıcıyı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await _deleteUser();
    }
  }

  Future<void> _deleteUser() async {
    try {
      final response = await http.delete(
        Uri.parse('${widget.baseUrl}/users/${widget.user['username']}'),
      );

      if (response.statusCode == 200) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kullanıcı başarıyla silindi!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Kullanıcı silinemedi! Hata: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Beklenmeyen bir hata oluştu!")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Düzenle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.purple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                      labelText: 'Kullanıcı Adı',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                      labelText: 'Yeni Şifre (isteğe bağlı)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                  obscureText: true,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _unit,
                  decoration: InputDecoration(
                      labelText: 'Birim Seçiniz',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                  items: _units
                      .map((unit) =>
                          DropdownMenuItem(value: unit, child: Text(unit)))
                      .toList(),
                  onChanged: (value) => setState(() => _unit = value!),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: InputDecoration(
                      labelText: 'Yetki',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10))),
                  items: ['User', 'Admin']
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) => setState(() => _role = value!),
                ),
                SizedBox(height: 180),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _updateUser,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: Text('Güncelle',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmDeleteUser,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: Text('Kullanıcıyı Sil',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
